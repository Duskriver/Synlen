import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import 'package:path/path.dart' as p;
import 'package:saf_stream/saf_stream.dart';
import 'backup_archive_guard.dart';
import 'backup_paths.dart';
import 'native_file_picker.dart';
import 'platform_path.dart';
import 'importable_epub.dart';
import 'import_cache_manager.dart';

/// Unified entry point for EPUB file import across platforms
///
/// This service provides a clean, platform-agnostic API for:
/// - Picking EPUB files (single or multiple)
/// - Picking folders and scanning for EPUB files
/// - Processing selected files into cached, hashed ImportableEpub objects
///
/// Android: Uses native MethodChannel with SAF (Storage Access Framework)
/// iOS: Uses UIDocumentPickerViewController via native MethodChannel
class UnifiedImportService {
  final _safStream = SafStream();

  final NativeFilePicker _picker;

  // Use `late final` so we can pass `fetchIosFileToTemp` as a callback
  // into ImportCacheManager without a circular-reference problem.
  late final ImportCacheManager _cacheManager;

  UnifiedImportService({
    ImportCacheManager? cacheManager,
    NativeFilePicker? picker,
  }) : _picker = picker ?? NativeFilePicker() {
    _cacheManager =
        cacheManager ??
        ImportCacheManager(iosFetchCallback: fetchIosFileToTemp);
  }

  /// Process an EPUB file into a cached, hashed ImportableEpub
  ///
  /// This delegates to [ImportCacheManager.createCacheAndHash] which:
  /// - For Android: Streams content from SAF URI to cache
  /// - For iOS: Copies file from file system to cache
  /// - Calculates SHA-256 hash for deduplication
  ///
  /// Returns [ImportableEpub] with cached file and hash.
  /// Throws exceptions on I/O errors or invalid files.
  Future<ImportableEpub> processEpub(PlatformPath path) async {
    final importable = await _cacheManager.createCacheAndHash(path);

    // SAF 数字文档 ID（如 .../document/1000000018）无法从 URI 推断真实
    // 文件名，缓存扩展名与 TXT 书名都会错；向原生查询显示名兜底。
    if (path is AndroidUriPath) {
      final displayName = await _picker.resolveDisplayName(path.uri);
      if (displayName != null && displayName.trim().isNotEmpty) {
        return ImportableEpub(
          cacheFile: importable.cacheFile,
          hash: importable.hash,
          originalName: displayName.trim(),
        );
      }
    }
    return importable;
  }

  /// Process a plain text file (e.g. shelf.json) into a String
  ///
  /// For Android: Streams content from SAF URI without loading entire file into memory
  /// For iOS: Reads file from file system
  ///
  /// Returns the file content as a String.
  /// Throws exceptions on I/O errors or invalid files.
  Future<String> processPlainFile(PlatformPath path) async {
    final bytes = await processBinaryFile(path);
    return utf8.decode(bytes);
  }

  /// Process a binary file (e.g. cover image) into bytes
  ///
  /// For Android: Streams content from SAF URI without loading entire file into memory
  /// For iOS: Reads file from file system
  ///
  /// Returns the file content as bytes.
  /// Throws exceptions on I/O errors or invalid files.
  Future<Uint8List> processBinaryFile(PlatformPath path) async {
    switch (path) {
      case AndroidUriPath(:final uri):
        return await _safStream.readFileBytes(uri);
      case IOSFilePath(path: final pathStr):
        // 1. Fetch just-in-time inside the active security scope.
        final tempPath = await _picker.fetchIosFileToTemp(pathStr);
        final tempFile = File(tempPath);
        // 2. Read into memory.
        final bytes = await tempFile.readAsBytes();
        // 3. Clean up the temp copy immediately.
        if (await tempFile.exists()) await tempFile.delete();
        return bytes;
    }
  }

  /// Extracts a picked ZIP backup into the import cache and classifies the
  /// entries into [BackupPaths].
  ///
  /// ZIP 原始字节不整体进内存：选取的文件先由缓存层落盘，再用
  /// [InputFileStream] 流式解码并逐条目写盘。返回的 rootPath 是导入缓存区内
  /// 的解压目录，恢复结束后由调用方负责删除。
  Future<BackupPaths> processBackupZip(PlatformPath zipPath) async {
    final cacheDir = await _cacheManager.getCacheDirectory();
    final extractDir = Directory(
      p.join(
        cacheDir.path,
        'backup_extract_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    File? rawZip;
    try {
      rawZip = await _cacheManager.createRawCacheFile(zipPath);
      final archive = ZipDecoder().decodeStream(InputFileStream(rawZip.path));
      // 解压前先静态校验整条 archive：数量/大小上限防 zip bomb，路径校验防越界。
      final violation = validateBackupArchiveEntries(
        archive.files.map((f) => (name: f.name, size: f.size)),
      );
      if (violation != null) {
        appLogger.w('备份 ZIP 未通过解压前校验: $violation');
        throw BackupArchiveViolationException(violation);
      }
      await extractArchiveToDisk(archive, extractDir.path);
    } catch (_) {
      await _deleteQuietly(extractDir);
      rethrow;
    } finally {
      if (rawZip != null) await _cacheManager.clean(rawZip);
      // 选取的 ZIP 已缓存落盘，安全作用域到此即可释放。
      await releaseIosAccess();
    }

    final entries = extractDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map(
          (file) => (
            displayPath: file.path,
            platformPath: IOSFilePath(file.path) as PlatformPath,
          ),
        )
        .toList();

    final classified = classifyBackupEntries(entries);
    if (classified.shelfFile == null) {
      await _deleteQuietly(extractDir);
      throw Exception(
        'Invalid backup: ${AppStorageConstants.shelfFile} not found',
      );
    }

    final bookPaths = buildBackupBookPaths(classified.tempBookComponents);
    final rootPath = p.dirname((classified.shelfFile! as IOSFilePath).path);
    return BackupPaths(
      rootPath: IOSFilePath(rootPath),
      shelfFile: classified.shelfFile!,
      bookPaths: bookPaths,
    );
  }

  Future<void> _deleteQuietly(Directory dir) async {
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (e) {
      appLogger.w('Backup extract cleanup failed: $e');
    }
  }

  /// Clean up a cached file
  ///
  /// Delegates to [ImportCacheManager.clean]
  Future<void> cleanCache(File cacheFile) async {
    await _cacheManager.clean(cacheFile);
  }

  /// Caches a font file from a [PlatformPath] into the import cache directory.
  ///
  /// Preserves the original file extension. The caller is responsible for
  /// deleting the returned [File] via [cleanCache] when done.
  Future<File> processFontFile(PlatformPath path) async {
    return await _cacheManager.createRawCacheFile(path);
  }

  // ==================== Android Implementation ====================

  // ==================== iOS Implementation ====================

  // ==================== Font File Picker Implementations ====================

  // ==================== 平台选择器（委托 NativeFilePicker） ====================

  /// 选择多个 EPUB 文件；取消或不可用时返回空列表。
  Future<List<PlatformPath>> pickFiles() => _picker.pickFiles();

  /// 选择文件夹并递归扫描 EPUB 文件。
  Future<List<PlatformPath>> pickFolder() => _picker.pickFolder();

  /// 选择备份目录并返回其真实文件系统路径。
  Future<BackupPaths?> pickBackupFolder() => _picker.pickBackupFolder();

  /// 选择单个备份 ZIP 文件。
  Future<PlatformPath?> pickBackupZipFile() => _picker.pickBackupZipFile();

  /// 选择字体文件（.ttf / .otf）。
  Future<List<PlatformPath>> pickFontFiles() => _picker.pickFontFiles();

  /// 请求 Swift 在安全作用域内把 [originalPath] 复制到临时目录。
  Future<String> fetchIosFileToTemp(String originalPath) =>
      _picker.fetchIosFileToTemp(originalPath);

  /// 释放原生侧持有的全部安全作用域访问。
  Future<void> releaseIosAccess() => _picker.releaseIosAccess();

  // ==================== Utility Methods ====================

  /// Clear all cached import files
  ///
  /// Use with caution as this removes all temporary import cache.
  Future<void> clearAllCache() async {
    await _cacheManager.clearAll();
  }
}
