// ----------------------------------------------------------------------------
// font_obfuscation.rs  –  EPUB 字体混淆（font obfuscation）的判定与还原
//
// 纯函数模块：不接触文件系统与全局缓存，全部输入输出都是字符串与字节，
// 便于单测。与 ZIP/IO 的接线在 api/epub.rs。
//
// 支持 OCF 规范中的两种字体混淆算法：
//
//   IDPF（http://www.idpf.org/2008/embedding，EPUB 3 标准）
//     key = 对 unique-identifier 去掉所有空白字符后的 UTF-8 字节做 SHA-1
//           （20 字节），对资源前 1040 字节循环 XOR。
//
//   Adobe（http://ns.adobe.com/pdf/enc#RC，EPUB 2 常见）
//     key = unique-identifier 中的 UUID（urn:uuid:xxxxxxxx-...）去掉
//           "urn:uuid:" 前缀与连字符后的 16 字节原始字节，
//           对资源前 1024 字节循环 XOR。
// ----------------------------------------------------------------------------

use std::collections::HashMap;

use quick_xml::events::Event;
use quick_xml::Reader;
use sha1::{Digest, Sha1};

use crate::api::epub::normalize_path;

/// IDPF 字体混淆算法标识（EPUB 3 标准）。
pub const IDPF_ALGORITHM: &str = "http://www.idpf.org/2008/embedding";
/// Adobe 字体混淆算法标识（EPUB 2 常见）。
pub const ADOBE_ALGORITHM: &str = "http://ns.adobe.com/pdf/enc#RC";

/// encryption.xml 中的一条加密记录。
pub struct EncryptedEntry {
    /// 目标资源的容器相对路径（CipherReference URI，未做百分号解码）。
    pub uri: String,
    /// EncryptionMethod 的 Algorithm 属性原值。
    pub algorithm: String,
}

/// 已知的字体混淆算法及其还原参数。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ObfuscationMethod {
    Idpf,
    Adobe,
}

impl ObfuscationMethod {
    /// 未知算法返回 None（DRM 等其他加密不在支持范围）。
    pub fn from_algorithm(algorithm: &str) -> Option<Self> {
        match algorithm {
            IDPF_ALGORITHM => Some(Self::Idpf),
            ADOBE_ALGORITHM => Some(Self::Adobe),
            _ => None,
        }
    }

    /// 混淆只覆盖资源的开头若干字节，其余原样。
    pub fn prefix_len(self) -> usize {
        match self {
            Self::Idpf => 1040,
            Self::Adobe => 1024,
        }
    }

    /// 由 OPF unique-identifier 派生 XOR key；Adobe 算法拿不到合法 UUID 时返回 None。
    pub fn derive_key(self, identifier: &str) -> Option<Vec<u8>> {
        match self {
            Self::Idpf => Some(idpf_key(identifier)),
            Self::Adobe => adobe_key(identifier),
        }
    }
}

/// 单个混淆字体的还原参数：XOR key 与参与混淆的前缀长度。
pub struct FontObfuscation {
    pub key: Vec<u8>,
    pub prefix_len: usize,
}

/// IDPF key：unique-identifier 去掉所有 XML 空白字符后的 SHA-1（20 字节）。
pub fn idpf_key(identifier: &str) -> Vec<u8> {
    let cleaned: Vec<u8> = identifier
        .bytes()
        .filter(|b| !b.is_ascii_whitespace())
        .collect();
    let mut hasher = Sha1::new();
    hasher.update(&cleaned);
    hasher.finalize().to_vec()
}

/// Adobe key：取 identifier 中的 UUID，去掉 "urn:uuid:" 前缀与连字符，
/// 解析为 16 字节原始字节；identifier 不含合法 UUID 时返回 None。
pub fn adobe_key(identifier: &str) -> Option<Vec<u8>> {
    let cleaned: String = identifier.chars().filter(|c| !c.is_whitespace()).collect();
    let without_prefix = cleaned.strip_prefix("urn:uuid:").unwrap_or(&cleaned);
    let hex_part: String = without_prefix.chars().filter(|&c| c != '-').collect();
    if hex_part.len() != 32 {
        return None;
    }
    (0..16)
        .map(|i| u8::from_str_radix(&hex_part[i * 2..i * 2 + 2], 16).ok())
        .collect()
}

/// 就地还原：对前 prefix_len 字节循环 XOR；不足前缀长度的短资源按实际长度处理。
pub fn deobfuscate(data: &mut [u8], obfuscation: &FontObfuscation) {
    let key_len = obfuscation.key.len();
    if key_len == 0 {
        return;
    }
    let n = obfuscation.prefix_len.min(data.len());
    for (i, byte) in data.iter_mut().take(n).enumerate() {
        *byte ^= obfuscation.key[i % key_len];
    }
}

/// 解析 encryption.xml，抽出全部 EncryptedData 的 (URI, Algorithm)。
/// 元素名按本地名匹配，忽略命名空间前缀（enc: / 默认命名空间都常见）。
pub fn parse_encryption_xml(encryption_xml: &str) -> Vec<EncryptedEntry> {
    let mut reader = Reader::from_str(encryption_xml);
    let mut entries = Vec::new();
    // 当前 EncryptedData 内已收集到的 Algorithm / URI
    let mut current: Option<(Option<String>, Option<String>)> = None;

    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) => match local_name(e.name().as_ref()) {
                "EncryptedData" => current = Some((None, None)),
                "EncryptionMethod" => {
                    if let Some(entry) = current.as_mut() {
                        entry.0 = attr_value(&e, "Algorithm");
                    }
                }
                "CipherReference" => {
                    if let Some(entry) = current.as_mut() {
                        entry.1 = attr_value(&e, "URI");
                    }
                }
                _ => {}
            },
            Ok(Event::Empty(e)) => match local_name(e.name().as_ref()) {
                "EncryptedData" => {
                    if let Some((algorithm, uri)) = current.take() {
                        push_entry(&mut entries, algorithm, uri);
                    }
                }
                "EncryptionMethod" => {
                    if let Some(entry) = current.as_mut() {
                        entry.0 = attr_value(&e, "Algorithm");
                    }
                }
                "CipherReference" => {
                    if let Some(entry) = current.as_mut() {
                        entry.1 = attr_value(&e, "URI");
                    }
                }
                _ => {}
            },
            Ok(Event::End(e)) => {
                if local_name(e.name().as_ref()) == "EncryptedData" {
                    if let Some((algorithm, uri)) = current.take() {
                        push_entry(&mut entries, algorithm, uri);
                    }
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }
    entries
}

/// 只有 Algorithm 与 URI 都存在的条目才有效。
fn push_entry(entries: &mut Vec<EncryptedEntry>, algorithm: Option<String>, uri: Option<String>) {
    if let (Some(algorithm), Some(uri)) = (algorithm, uri) {
        entries.push(EncryptedEntry { uri, algorithm });
    }
}

/// 解析 container.xml，取第一个 rootfile 的 full-path（OPF 的包内路径）。
pub fn find_rootfile_path(container_xml: &str) -> Option<String> {
    let mut reader = Reader::from_str(container_xml);
    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) | Ok(Event::Empty(e)) => {
                if local_name(e.name().as_ref()) == "rootfile" {
                    if let Some(path) = attr_value(&e, "full-path") {
                        return Some(path);
                    }
                }
            }
            Ok(Event::Eof) => return None,
            Err(_) => return None,
            _ => {}
        }
    }
}

/// 解析 OPF，取 unique-identifier 字符串：
/// 优先 package@unique-identifier 指向的 dc:identifier，缺席时取第一个 dc:identifier。
pub fn unique_identifier(opf_xml: &str) -> Option<String> {
    let mut reader = Reader::from_str(opf_xml);
    reader.config_mut().trim_text(true);

    let mut wanted_id: Option<String> = None;
    let mut first_identifier: Option<String> = None;
    let mut by_id: Vec<(String, String)> = Vec::new();
    // 当前位于 dc:identifier 元素内时，其 id 属性值
    let mut current_identifier_id: Option<Option<String>> = None;

    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) => match local_name(e.name().as_ref()) {
                "package" => wanted_id = attr_value(&e, "unique-identifier"),
                "identifier" => {
                    current_identifier_id = Some(attr_value(&e, "id"));
                }
                _ => {}
            },
            Ok(Event::Empty(e)) => {
                if local_name(e.name().as_ref()) == "package" {
                    wanted_id = attr_value(&e, "unique-identifier");
                }
            }
            Ok(Event::Text(t)) => {
                if let Some(id) = current_identifier_id.take() {
                    let text = t.trim().to_owned();
                    if !text.is_empty() {
                        if first_identifier.is_none() {
                            first_identifier = Some(text.clone());
                        }
                        if let Some(id) = id {
                            by_id.push((id, text));
                        }
                    }
                }
            }
            Ok(Event::End(e)) => {
                if local_name(e.name().as_ref()) == "identifier" {
                    current_identifier_id = None;
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }

    if let Some(wanted) = wanted_id {
        if let Some((_, text)) = by_id.iter().find(|(id, _)| *id == wanted) {
            return Some(text.clone());
        }
    }
    first_identifier
}

/// 解析 OPF manifest，返回 (href 原值, media-type) 列表。
pub fn manifest_media_types(opf_xml: &str) -> Vec<(String, String)> {
    let mut reader = Reader::from_str(opf_xml);
    let mut items = Vec::new();
    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) | Ok(Event::Empty(e)) => {
                if local_name(e.name().as_ref()) == "item" {
                    if let (Some(href), Some(media_type)) = (
                        attr_value(&e, "href"),
                        attr_value(&e, "media-type"),
                    ) {
                        items.push((href, media_type));
                    }
                }
            }
            Ok(Event::Eof) => break,
            Err(_) => break,
            _ => {}
        }
    }
    items
}

/// OPF manifest 中的字体 media-type 闭集（OCF 只豁免字体资源的混淆）。
pub fn is_font_media_type(media_type: &str) -> bool {
    matches!(
        media_type,
        "application/vnd.ms-opentype"
            | "application/font-woff"
            | "application/x-font-ttf"
            | "application/x-font-opentype"
            | "application/x-font-truetype"
            | "font/ttf"
            | "font/otf"
            | "font/woff"
            | "font/woff2"
    )
}

/// 构建「混淆字体条目 → 还原参数」映射。
///
/// 只收录同时满足两条的 EncryptedData：算法是 IDPF/Adobe 之一，
/// 且目标资源在 OPF manifest 中的 media-type 是字体。
/// 其余条目（未知算法、加密内容文档）被忽略——是否放行由导入侧决定，
/// 这里只保证不盲目 XOR 非字体资源。
pub fn build_obfuscation_map(
    encryption_xml: &str,
    opf_xml: &str,
    opf_dir: &str,
) -> HashMap<String, FontObfuscation> {
    let mut map = HashMap::new();

    let Some(identifier) = unique_identifier(opf_xml) else {
        return map;
    };

    // manifest 的 href 相对 OPF 所在目录解析成容器内完整路径，作为查找键
    let font_paths: Vec<String> = manifest_media_types(opf_xml)
        .into_iter()
        .filter(|(_, media_type)| is_font_media_type(media_type))
        .map(|(href, _)| {
            let joined = if opf_dir.is_empty() {
                href
            } else {
                format!("{opf_dir}/{href}")
            };
            percent_decode(&normalize_path(&joined))
        })
        .collect();

    for entry in parse_encryption_xml(encryption_xml) {
        let Some(method) = ObfuscationMethod::from_algorithm(&entry.algorithm) else {
            continue;
        };
        let uri = percent_decode(&normalize_path(&entry.uri));
        if !font_paths.iter().any(|p| *p == uri) {
            continue;
        }
        let Some(key) = method.derive_key(&identifier) else {
            continue;
        };
        map.insert(
            uri,
            FontObfuscation {
                key,
                prefix_len: method.prefix_len(),
            },
        );
    }
    map
}

/// 取限定名的本地部分（去掉命名空间前缀）。
fn local_name(qname: &str) -> &str {
    match qname.find(':') {
        Some(i) => &qname[i + 1..],
        None => qname,
    }
}

/// 读属性值并反转义 XML 实体；属性缺席或非法返回 None。
///
/// quick-xml 0.42 起名字与属性值统一按 UTF-8 处理：`Reader::decoder` 已移除，
/// `BytesStart::try_get_attribute` 接收 `&str`，属性值按 XML 1.0 规则归一化。
fn attr_value(e: &quick_xml::events::BytesStart, name: &str) -> Option<String> {
    let attr = e.try_get_attribute(name).ok()??;
    attr.normalized_value(quick_xml::XmlVersion::Implicit1_0)
        .ok()
        .map(|v| v.into_owned())
}

/// 百分号解码 URI 路径（%XX → 对应字节，按 UTF-8 组装；非法序列原样保留）。
/// 不处理 '+'——URI path 中它是字面字符。
fn percent_decode(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let (Some(h), Some(l)) = (hex_val(&bytes[i + 1]), hex_val(&bytes[i + 2])) {
                out.push(h * 16 + l);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8(out).unwrap_or_else(|e| String::from_utf8_lossy(e.as_bytes()).into_owned())
}

fn hex_val(b: &u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const IDENTIFIER: &str = "urn:uuid:9c6f6f34-2f0c-4b32-9e60-5f05e8c1a2b3";

    // ------------------------------------------------------------------
    // key 派生
    // ------------------------------------------------------------------

    #[test]
    fn idpf_key_strips_whitespace_and_matches_sha1() {
        let key = idpf_key(IDENTIFIER);
        assert_eq!(key.len(), 20);
        // 已知答案：sha1("urn:uuid:9c6f6f34-2f0c-4b32-9e60-5f05e8c1a2b3")
        assert_eq!(
            key,
            vec![
                0xfe, 0xaf, 0x0c, 0x34, 0xfb, 0x1d, 0xa4, 0x46, 0x68, 0xaa, 0xb6, 0xcd, 0x3a, 0xf8,
                0x34, 0x7f, 0x8c, 0xf1, 0x81, 0x9e
            ]
        );
        // 空白字符不参与 key
        let with_spaces = "  urn:uuid:9c6f6f34-2f0c-4b32-9e60-5f05e8c1a2b3\n";
        assert_eq!(idpf_key(with_spaces), key);
    }

    #[test]
    fn adobe_key_decodes_uuid_bytes() {
        let key = adobe_key(IDENTIFIER).expect("valid UUID");
        assert_eq!(
            key,
            vec![
                0x9c, 0x6f, 0x6f, 0x34, 0x2f, 0x0c, 0x4b, 0x32, 0x9e, 0x60, 0x5f, 0x05, 0xe8, 0xc1,
                0xa2, 0xb3
            ]
        );
        // 容忍空白
        assert_eq!(
            adobe_key(" urn:uuid:9c6f6f34-2f0c-4b32-9e60-5f05e8c1a2b3 "),
            Some(key)
        );
        // 非 UUID identifier 派生失败
        assert_eq!(adobe_key("978-7-121-00000-0"), None);
    }

    // ------------------------------------------------------------------
    // XOR 还原（含 1040 / 1024 字节边界）
    // ------------------------------------------------------------------

    #[test]
    fn deobfuscate_idpf_xors_first_1040_bytes() {
        let key: Vec<u8> = (0u8..20).collect();
        let mut data: Vec<u8> = (0..1100u32).map(|i| (i % 256) as u8).collect();
        let original = data.clone();
        let obf = FontObfuscation {
            key: key.clone(),
            prefix_len: 1040,
        };
        deobfuscate(&mut data, &obf);

        for i in 0..1040 {
            assert_eq!(data[i], original[i] ^ key[i % 20], "byte {i} must be XORed");
        }
        assert_eq!(
            &data[1040..],
            &original[1040..],
            "bytes past the 1040-byte prefix must stay untouched"
        );
    }

    #[test]
    fn deobfuscate_adobe_xors_first_1024_bytes() {
        let key: Vec<u8> = (0u8..16).map(|i| i * 3).collect();
        let mut data: Vec<u8> = (0..1050u32).map(|i| (i % 256) as u8).collect();
        let original = data.clone();
        let obf = FontObfuscation {
            key: key.clone(),
            prefix_len: 1024,
        };
        deobfuscate(&mut data, &obf);

        for i in 0..1024 {
            assert_eq!(data[i], original[i] ^ key[i % 16], "byte {i} must be XORed");
        }
        assert_eq!(
            &data[1024..],
            &original[1024..],
            "bytes past the 1024-byte prefix must stay untouched"
        );
    }

    #[test]
    fn deobfuscate_short_resource_stops_at_data_len() {
        let mut data = vec![0xAAu8; 10];
        let obf = FontObfuscation {
            key: vec![0xFF],
            prefix_len: 1040,
        };
        deobfuscate(&mut data, &obf);
        assert_eq!(data, vec![0x55u8; 10]);
    }

    #[test]
    fn deobfuscate_roundtrip_restores_original() {
        let key = idpf_key(IDENTIFIER);
        let original: Vec<u8> = (0..2000u32).map(|i| (i % 256) as u8).collect();
        let obf = FontObfuscation {
            key: key.clone(),
            prefix_len: 1040,
        };
        let mut obfuscated = original.clone();
        deobfuscate(&mut obfuscated, &obf);
        assert_ne!(obfuscated[..1040], original[..1040]);
        deobfuscate(&mut obfuscated, &obf);
        assert_eq!(obfuscated, original);
    }

    // ------------------------------------------------------------------
    // encryption.xml 解析与判定
    // ------------------------------------------------------------------

    fn sample_opf() -> String {
        format!(
            r#"<?xml version="1.0"?>
<package version="3.0" unique-identifier="book-id" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">{IDENTIFIER}</dc:identifier>
    <dc:title>Sample</dc:title>
  </metadata>
  <manifest>
    <item id="ch1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="font1" href="fonts/serif.otf" media-type="application/vnd.ms-opentype"/>
  </manifest>
</package>"#
        )
    }

    #[test]
    fn parse_encryption_xml_extracts_entries() {
        let xml = r#"<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <enc:EncryptedData xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
    <enc:EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <enc:CipherData>
      <enc:CipherReference URI="OEBPS/fonts/serif.otf"/>
    </enc:CipherData>
  </enc:EncryptedData>
  <EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#">
    <EncryptionMethod Algorithm="http://ns.adobe.com/pdf/enc#RC"/>
    <CipherData>
      <CipherReference URI="OEBPS/fonts/mono.ttf"/>
    </CipherData>
  </EncryptedData>
</encryption>"#;
        let entries = parse_encryption_xml(xml);
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].uri, "OEBPS/fonts/serif.otf");
        assert_eq!(entries[0].algorithm, IDPF_ALGORITHM);
        assert_eq!(entries[1].uri, "OEBPS/fonts/mono.ttf");
        assert_eq!(entries[1].algorithm, ADOBE_ALGORITHM);
    }

    #[test]
    fn build_map_accepts_font_with_known_algorithm() {
        let encryption_xml = r#"<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#">
    <EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <CipherData><CipherReference URI="OEBPS/fonts/serif.otf"/></CipherData>
  </EncryptedData>
</encryption>"#;
        let map = build_obfuscation_map(encryption_xml, &sample_opf(), "OEBPS");
        let obf = map
            .get("OEBPS/fonts/serif.otf")
            .expect("font entry must be accepted");
        assert_eq!(obf.prefix_len, 1040);
        assert_eq!(obf.key, idpf_key(IDENTIFIER));
    }

    #[test]
    fn build_map_rejects_unknown_algorithm() {
        let encryption_xml = r#"<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#">
    <EncryptionMethod Algorithm="http://readium.org/2014/01/lcp"/>
    <CipherData><CipherReference URI="OEBPS/fonts/serif.otf"/></CipherData>
  </EncryptedData>
</encryption>"#;
        let map = build_obfuscation_map(encryption_xml, &sample_opf(), "OEBPS");
        assert!(map.is_empty(), "unknown algorithm must not be deobfuscated");
    }

    #[test]
    fn build_map_rejects_non_font_target() {
        let encryption_xml = r#"<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#">
    <EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/>
    <CipherData><CipherReference URI="OEBPS/chapter1.xhtml"/></CipherData>
  </EncryptedData>
</encryption>"#;
        let map = build_obfuscation_map(encryption_xml, &sample_opf(), "OEBPS");
        assert!(
            map.is_empty(),
            "encrypted content documents must not be XORed"
        );
    }

    // ------------------------------------------------------------------
    // OPF / container.xml 辅助解析
    // ------------------------------------------------------------------

    #[test]
    fn unique_identifier_prefers_package_unique_identifier_attr() {
        let opf = format!(
            r#"<package unique-identifier="primary" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="other">other-value</dc:identifier>
    <dc:identifier id="primary">{IDENTIFIER}</dc:identifier>
  </metadata>
</package>"#
        );
        assert_eq!(unique_identifier(&opf).as_deref(), Some(IDENTIFIER));
    }

    #[test]
    fn unique_identifier_falls_back_to_first_identifier() {
        let opf = r#"<package xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier>fallback-id</dc:identifier>
  </metadata>
</package>"#;
        assert_eq!(unique_identifier(opf).as_deref(), Some("fallback-id"));
    }

    #[test]
    fn find_rootfile_path_reads_full_path() {
        let container = r#"<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#;
        assert_eq!(
            find_rootfile_path(container).as_deref(),
            Some("OEBPS/content.opf")
        );
    }

    #[test]
    fn percent_decode_handles_utf8_and_literals() {
        assert_eq!(
            percent_decode("fonts/%E5%AE%8B%E4%BD%93.otf"),
            "fonts/宋体.otf"
        );
        assert_eq!(percent_decode("a+b.ttf"), "a+b.ttf");
        assert_eq!(percent_decode("plain.otf"), "plain.otf");
    }
}
