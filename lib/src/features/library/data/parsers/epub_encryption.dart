part of 'epub_zip_parser.dart';

/// OCF encryption.xml 判定：区分"仅字体混淆"与真正的 DRM。
///
/// EPUB 规范的字体混淆只豁免两种算法，且目标只能是字体资源：
/// - IDPF：`http://www.idpf.org/2008/embedding`（EPUB 3 标准）
/// - Adobe：`http://ns.adobe.com/pdf/enc#RC`（EPUB 2 常见）
///
/// 判定规则：encryption.xml 中每个 EncryptedData 都满足「算法是上述两种之一
/// 且目标资源在 OPF manifest 中的 media-type 是字体」→ 仅字体混淆，放行导入；
/// 其余（未知算法、加密了内容文档、清单不可解析）一律按 DRM 拒绝，返回
/// [LibraryErrorCode.drmProtected] 错误，presentation 按码映射为 l10n 文案。
const _idpfObfuscationAlgorithm = 'http://www.idpf.org/2008/embedding';
const _adobeObfuscationAlgorithm = 'http://ns.adobe.com/pdf/enc#RC';

/// OPF manifest 中的字体 media-type 闭集。
const _fontMediaTypes = {
  'application/vnd.ms-opentype',
  'application/font-woff',
  'application/x-font-ttf',
  'application/x-font-opentype',
  'application/x-font-truetype',
  'font/ttf',
  'font/otf',
  'font/woff',
  'font/woff2',
};

/// 校验 encryption.xml：返回 null 表示放行（仅字体混淆），否则返回 DRM 拒绝
/// 错误（details 记录拒绝原因，仅入日志）。
///
/// [opfContent] / [opfPath] 用于解析 manifest 的 media-type：
/// CipherReference 的 URI 是容器根相对路径，manifest 的 href 相对 OPF 目录，
/// 两侧都归一化为容器内完整路径后比较。
LibraryException? _validateEncryption(
  ArchiveFile encryptionFile,
  String opfContent,
  String opfPath,
) {
  final XmlDocument encryptionDoc;
  try {
    encryptionDoc = XmlDocument.parse(
      _decodeString(encryptionFile.content as List<int>),
    );
  } catch (e) {
    return LibraryException(
      LibraryErrorCode.drmProtected,
      'encryption manifest is malformed: $e',
    );
  }

  final opfDir = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/'))
      : '';
  final mediaTypes = _manifestMediaTypes(opfContent, opfDir);

  for (final data in encryptionDoc.descendantElements.where(
    (e) => e.localName == 'EncryptedData',
  )) {
    final algorithm = data.descendantElements
        .where((e) => e.localName == 'EncryptionMethod')
        .firstOrNull
        ?.getAttribute('Algorithm');
    final uri = data.descendantElements
        .where((e) => e.localName == 'CipherReference')
        .firstOrNull
        ?.getAttribute('URI');

    final isKnownAlgorithm =
        algorithm == _idpfObfuscationAlgorithm ||
        algorithm == _adobeObfuscationAlgorithm;
    if (!isKnownAlgorithm) {
      return LibraryException(
        LibraryErrorCode.drmProtected,
        'unsupported encryption algorithm: ${algorithm ?? "unknown"}',
      );
    }
    if (uri == null) {
      return const LibraryException(
        LibraryErrorCode.drmProtected,
        'encryption entry is missing target URI',
      );
    }

    final mediaType = mediaTypes[_normalizeEncryptionUri(uri)];
    if (mediaType == null || !_fontMediaTypes.contains(mediaType)) {
      return LibraryException(
        LibraryErrorCode.drmProtected,
        'encrypted resource is not a font: $uri',
      );
    }
  }
  return null;
}

/// OPF manifest 的 media-type 表：容器内完整路径 → media-type。
Map<String, String> _manifestMediaTypes(String opfContent, String opfDir) {
  final doc = XmlDocument.parse(opfContent);
  final result = <String, String>{};
  for (final item in doc.rootElement.descendantElements.where(
    (e) => e.localName == 'item',
  )) {
    final href = item.getAttribute('href');
    final mediaType = item.getAttribute('media-type');
    if (href != null && mediaType != null) {
      final joined = opfDir.isEmpty ? href : '$opfDir/$href';
      result[_normalizeEncryptionUri(joined)] = mediaType;
    }
  }
  return result;
}

/// 归一化 encryption.xml URI / manifest href 供比较：
/// 百分号解码、去前导 `/` 与 `./`、压缩重复斜杠。
String _normalizeEncryptionUri(String uri) {
  var s = uri.trim();
  try {
    s = Uri.decodeFull(s);
  } catch (_) {
    // 非法百分号序列按原样比较
  }
  while (s.startsWith('/')) {
    s = s.substring(1);
  }
  while (s.startsWith('./')) {
    s = s.substring(2);
  }
  return s.replaceAll(RegExp(r'/+'), '/');
}
