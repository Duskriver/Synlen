// ----------------------------------------------------------------------------
// epub.rs  –  EPUB file backend for the Flutter reader
//
// Architecture
// ============
//
//   load_epub
//     Opens the file once, drives rc-zip's ArchiveFsm to parse the ZIP
//     central directory (no decompression), and stores the result in a
//     global RwLock<HashMap<String, Arc<CachedArchive>>>.
//     Subsequent calls for the same path are instant no-ops (idempotent).
//
//   read_epub_file
//     1. Clones Arc<CachedArchive> while holding the read-lock for < 1 µs.
//     2. Looks up the normalised entry path in the pre-built index (O(1)).
//     3. Opens a *fresh* file handle (no lock held) and drives EntryFsm,
//        reading sequentially from the entry's header_offset.
//     => N concurrent WebView interception requests decompress in parallel
//        with zero lock contention.
//
//   close_epub
//     Drops the cached entry to free memory once the reader is closed.
// ----------------------------------------------------------------------------

use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::sync::Arc;

use once_cell::sync::Lazy;
use parking_lot::RwLock;
use positioned_io::ReadAt;
use rc_zip::fsm::{ArchiveFsm, EntryFsm, FsmResult};
use rc_zip::parse::{Archive, Entry};

use crate::font_obfuscation::{self, FontObfuscation};

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

/// Maximum accepted uncompressed size for a single entry (zip-bomb guard).
const MAX_UNCOMPRESSED_BYTES: u64 = 50 * 1024 * 1024; // 50 MiB

// ---------------------------------------------------------------------------
// Global cache
// ---------------------------------------------------------------------------

/// Everything we need to serve reads for a single EPUB without re-parsing.
struct CachedArchive {
    /// Parsed ZIP metadata (central directory only; no file content).
    archive: Archive,
    /// Normalised entry name → index into `archive.entries()`.
    index: HashMap<String, usize>,
    /// 混淆字体的归一化路径 → 还原参数；仅字体混淆的 EPUB 非空。
    obfuscated_fonts: HashMap<String, FontObfuscation>,
}

static EPUB_CACHE: Lazy<RwLock<HashMap<String, Arc<CachedArchive>>>> =
    Lazy::new(|| RwLock::new(HashMap::new()));

// ---------------------------------------------------------------------------
// Path normalisation
// ---------------------------------------------------------------------------

/// Canonicalise an entry path for lookup:
///   - backslashes → forward slashes
///   - strip all leading `/` and `./` prefixes
pub(crate) fn normalize_path(name: &str) -> String {
    let s = name.replace('\\', "/");
    let mut s: &str = s.as_str();
    loop {
        let stripped = s.trim_start_matches('/').trim_start_matches("./");
        if stripped.len() == s.len() {
            break;
        }
        s = stripped;
    }
    s.to_owned()
}

/// Check if the path looks like a media file
fn is_media_file(path: &str) -> bool {
    let ext = path.rsplit('.').next().unwrap_or("").to_lowercase();
    matches!(
        ext.as_str(),
        "mp4" | "mp3" | "ogg" | "webm" | "wav" | "m4a" | "avi" | "mov"
    )
}

// ---------------------------------------------------------------------------
// One-shot ZIP central-directory parsing via ArchiveFsm + positioned I/O
// ---------------------------------------------------------------------------

/// Parse only the central directory of the ZIP/EPUB at the given open file.
/// Uses positioned I/O (`ReadAt`) so the file pointer is never moved and
/// the same `File` handle can be used safely from multiple threads.
fn parse_central_directory(file: &File, file_size: u64) -> Result<Archive, String> {
    let mut fsm = ArchiveFsm::new(file_size);
    loop {
        if let Some(offset) = fsm.wants_read() {
            let space = fsm.space();
            let n = file
                .read_at(offset, space)
                .map_err(|e| format!("read_at {offset}: {e}"))?;
            if n == 0 {
                return Err("unexpected EOF while reading ZIP central directory".to_string());
            }
            fsm.fill(n);
        }
        match fsm
            .process()
            .map_err(|e| format!("invalid ZIP/EPUB structure: {e}"))?
        {
            FsmResult::Continue(next) => fsm = next,
            FsmResult::Done(archive) => return Ok(archive),
        }
    }
}

// ---------------------------------------------------------------------------
// Public API (called from Dart via flutter_rust_bridge)
// ---------------------------------------------------------------------------

/// Parse the ZIP central directory for the EPUB at `epub_path` and cache the
/// result.  No decompression occurs here.
///
/// Idempotent: a second call for the same path is a no-op and returns
/// immediately without any I/O.
pub fn load_epub(epub_path: String) -> Result<(), String> {
    // Fast path: already cached.
    {
        let guard = EPUB_CACHE.read();
        if guard.contains_key(&epub_path) {
            return Ok(());
        }
    }

    // Open file (used only for parsing; closed when this scope ends).
    let file =
        File::open(&epub_path).map_err(|e| format!("load_epub: cannot open '{epub_path}': {e}"))?;
    let file_size = file
        .metadata()
        .map_err(|e| format!("load_epub: cannot stat '{epub_path}': {e}"))?
        .len();

    // Parse the central directory once — no file content decompressed.
    let archive = parse_central_directory(&file, file_size)
        .map_err(|e| format!("load_epub: '{epub_path}': {e}"))?;

    // Build normalised-name → entry-index lookup table.
    let entry_count = archive.entries().count();
    let mut index: HashMap<String, usize> = HashMap::with_capacity(entry_count);
    for (i, entry) in archive.entries().enumerate() {
        index.insert(normalize_path(&entry.name), i);
    }

    // 仅字体混淆的 EPUB：现场解析 encryption.xml + OPF，派生还原参数。
    // 任何失败都退化为空映射（字体保持混淆），不阻断打开。
    let obfuscated_fonts = load_font_obfuscation(&epub_path, &archive, &index).unwrap_or_default();

    let cached = Arc::new(CachedArchive {
        archive,
        index,
        obfuscated_fonts,
    });

    let mut guard = EPUB_CACHE.write();
    // Another thread may have inserted while we were parsing; that is fine.
    guard.entry(epub_path).or_insert(cached);

    Ok(())
}

/// 读 `META-INF/encryption.xml` + container.xml + OPF，构建混淆字体映射。
///
/// 导入侧已拒绝含 DRM 的 EPUB，能走到这里的 encryption.xml 至多只剩
/// 字体混淆条目；任何一步解析失败都返回空映射（字体保持混淆原样供给），
/// 不让元数据瑕疵阻断阅读。
fn load_font_obfuscation(
    epub_path: &str,
    archive: &Archive,
    index: &HashMap<String, usize>,
) -> Option<HashMap<String, FontObfuscation>> {
    let read_utf8_entry = |name: &str| -> Option<String> {
        let &i = index.get(name)?;
        let entry = archive.entries().nth(i)?.clone();
        let bytes = read_entry_bytes(epub_path, entry).ok()?;
        String::from_utf8(bytes).ok()
    };

    let encryption_xml = read_utf8_entry("META-INF/encryption.xml")?;
    let container_xml = read_utf8_entry("META-INF/container.xml")?;
    let opf_path = font_obfuscation::find_rootfile_path(&container_xml)?;
    let opf_xml = read_utf8_entry(&normalize_path(&opf_path))?;
    let opf_dir = opf_path
        .rsplit_once('/')
        .map(|(dir, _)| dir)
        .unwrap_or_default();

    Some(font_obfuscation::build_obfuscation_map(
        &encryption_xml,
        &opf_xml,
        opf_dir,
    ))
}

/// Read and decompress a single file from the EPUB.
///
/// Returns:
///   `Ok(Some(bytes))` – file found and decompressed successfully.
///   `Ok(None)`        – the entry does not exist in this EPUB.
///   `Err(msg)`        – I/O error, corrupt data, or zip-bomb detected.
///
/// # Concurrency
/// The global read-lock is held **only** for `Arc::clone` (< 1 µs).
/// All I/O and decompression happen on a private file handle with no lock
/// held, so N threads can decompress different entries simultaneously.
pub fn read_epub_file(epub_path: String, file_path: String) -> Result<Option<Vec<u8>>, String> {
    let normalised = normalize_path(&file_path);

    if is_media_file(&normalised) {
        // Ignore media files to save memory.
        return Ok(Some(vec![]));
    }

    // 1. Clone Arc from cache — read-lock held for a single lookup + clone.
    let cached: Arc<CachedArchive> = {
        let guard = EPUB_CACHE.read();
        guard
            .get(&epub_path)
            .ok_or_else(|| "read_epub_file: EPUB not loaded; call load_epub first".to_string())?
            .clone()
    };
    // READ LOCK RELEASED HERE ------------------------------------------------

    // 2. Resolve the entry index via the pre-built normalised name map.
    let entry_index = match cached.index.get(&normalised) {
        Some(&i) => i,
        None => return Ok(None), // entry not present in this EPUB
    };

    // Retrieve and clone the entry metadata (cheap: stack-allocated struct +
    // a few small String clones for name/comment).
    let entry: Entry = cached
        .archive
        .entries()
        .nth(entry_index)
        .expect("entry index is always valid because it was built from the same archive")
        .clone();

    let mut out = read_entry_bytes(&epub_path, entry)?;

    // 命中混淆字体时还原前缀字节，再交给 WebView。
    if let Some(obfuscation) = cached.obfuscated_fonts.get(&normalised) {
        font_obfuscation::deobfuscate(&mut out, obfuscation);
    }
    Ok(Some(out))
}

/// 解压单个条目并返回完整字节流（含 50 MiB zip-bomb 上限校验）。
///
/// 在私有文件句柄上顺序解压，调用方不持有任何全局锁；
/// `read_epub_file` 与打开时的元数据读取共用此路径。
fn read_entry_bytes(epub_path: &str, entry: Entry) -> Result<Vec<u8>, String> {
    // Zip-bomb guard: reject entries that exceed the uncompressed-size cap.
    if entry.uncompressed_size > MAX_UNCOMPRESSED_BYTES {
        return Err(format!(
            "read_epub_file: entry uncompressed size {} exceeds the 50 MiB safety limit",
            entry.uncompressed_size
        ));
    }

    // Open a fresh, private file handle for this decompression task.
    // No global lock is held from this point onward.
    let mut file = File::open(epub_path)
        .map_err(|e| format!("read_epub_file: cannot open '{epub_path}': {e}"))?;

    // Seek to the local file header for this entry so EntryFsm can read
    // [local header] [compressed data] [optional data descriptor] in order.
    file.seek(SeekFrom::Start(entry.header_offset))
        .map_err(|e| format!("read_epub_file: seek to local header: {e}"))?;

    // Drive EntryFsm to decompress the entry.
    //
    //    EntryFsm handles:
    //      - parsing the local file header (may differ from central dir)
    //      - decompressing via the method recorded in the entry (Stored /
    //        Deflate / …) using rc-zip's built-in codec support
    //      - reading an optional trailing data descriptor
    //      - verifying the CRC-32 checksum
    //
    //    We pre-allocate the exact output size from the central-directory
    //    metadata and pass a sliding window of the remaining buffer to each
    //    `process()` call.
    let capacity = entry.uncompressed_size as usize;
    let mut out = vec![0u8; capacity];
    let mut out_pos: usize = 0;
    let mut fsm = EntryFsm::new(Some(entry), None);

    loop {
        // Feed compressed bytes into the FSM's input ring-buffer when needed.
        if fsm.wants_read() {
            let space = fsm.space();
            let n = file
                .read(space)
                .map_err(|e| format!("read_epub_file: read error: {e}"))?;
            fsm.fill(n);
        }

        // Offer the remaining output slice; the FSM writes decompressed bytes
        // directly into it and reports exactly how many were written.
        // Pre-compute the start index into a local to satisfy the borrow checker.
        let slice_start = out_pos.min(out.len());
        let out_slice = &mut out[slice_start..];
        match fsm
            .process(out_slice)
            .map_err(|e| format!("read_epub_file: decompression error: {e}"))?
        {
            FsmResult::Continue((next_fsm, outcome)) => {
                out_pos += outcome.bytes_written;
                fsm = next_fsm;
            }
            FsmResult::Done(_) => break,
        }
    }

    // Truncate to the actual byte count in case uncompressed_size was padded.
    out.truncate(out_pos);
    Ok(out)
}

/// Remove the cached metadata for `epub_path`.
/// Call this when the reader is closed to free memory.
pub fn close_epub(epub_path: String) {
    let mut guard = EPUB_CACHE.write();
    guard.remove(&epub_path);
}

