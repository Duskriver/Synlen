import 'dart:convert';
import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/data/services/epub_stream_service.dart';
import 'package:synlen/src/features/reader/data/services/txt_content_service.dart';
import 'package:synlen/src/features/reader/domain/xhtml_sanitizer.dart';

class _CachedResource {
  final Uint8List bytes;
  final String mimeType;

  const _CachedResource({required this.bytes, required this.mimeType});

  int get sizeInBytes => bytes.lengthInBytes;
}

/// 共享资源管线的解析结果。
class _ResolvedResource {
  final Uint8List bytes;
  final String mimeType;

  /// 是否命中内存缓存；Android 通道用它区分 'OK (Cached)' 与 'OK' 的 reasonPhrase。
  final bool fromCache;

  const _ResolvedResource({
    required this.bytes,
    required this.mimeType,
    required this.fromCache,
  });
}

/// WebView request handler for streaming book content
/// Intercepts requests to virtual domain and serves files from compressed EPUB,
/// 或从 TXT 单文件按字节范围切片包装为 XHTML。
class BookWebViewHandler {
  final EpubStreamService _streamService;
  final TxtContentService _txtContentService;

  /// 内存缓存，用于存储已加载的资源（CSS, 图片, 字体等）。
  /// 使用 LRU + 总字节数上限，避免长时间阅读时无限增长。
  static const int _maxCachedEntries = 256;
  static const int _maxCacheBytes = 24 * 1024 * 1024;
  static const int _maxCacheableEntryBytes = 2 * 1024 * 1024;
  final LinkedHashMap<String, _CachedResource> _resourceCache = LinkedHashMap();
  int _cachedBytes = 0;

  /// Virtual domain for EPUB content
  /// Format: book://localhost/book/{fileHash}/{filePath}
  static const String virtualDomain = 'localhost';
  static const String virtualScheme = 'book';
  static const _headers = {'Cache-Control': 'public, max-age=31536000'};

  BookWebViewHandler({
    required EpubStreamService streamService,
    required TxtContentService txtContentService,
  }) : _streamService = streamService,
       _txtContentService = txtContentService;

  /// 清空资源缓存（例如切换书籍时）
  void clearCache() {
    _resourceCache.clear();
    _cachedBytes = 0;
  }

  @visibleForTesting
  int get debugCachedResourceCount => _resourceCache.length;

  @visibleForTesting
  int get debugCachedBytes => _cachedBytes;

  _CachedResource? _getCachedResource(String url) {
    final cached = _resourceCache.remove(url);
    if (cached == null) {
      return null;
    }

    _resourceCache[url] = cached;
    return cached;
  }

  void _cacheResource(String url, Uint8List bytes, String mimeType) {
    if (bytes.lengthInBytes > _maxCacheableEntryBytes) {
      return;
    }

    final existing = _resourceCache.remove(url);
    if (existing != null) {
      _cachedBytes -= existing.sizeInBytes;
    }

    final resource = _CachedResource(bytes: bytes, mimeType: mimeType);
    _resourceCache[url] = resource;
    _cachedBytes += resource.sizeInBytes;
    _trimCache();
  }

  void _trimCache() {
    while (_resourceCache.length > _maxCachedEntries ||
        _cachedBytes > _maxCacheBytes) {
      final oldestKey = _resourceCache.keys.first;
      final removed = _resourceCache.remove(oldestKey);
      if (removed != null) {
        _cachedBytes -= removed.sizeInBytes;
      }
    }
  }

  /// Create WebView resource request handler
  /// This should be set as the shouldInterceptRequest callback
  Future<WebResourceResponse?> handleRequest({
    required String epubPath,
    required String fileHash,
    required WebUri requestUrl,
  }) async {
    try {
      final result = await _resolveResource(epubPath, fileHash, requestUrl);
      if (result.isLeft()) {
        // Android 通道对字体错误回退通用文案，不暴露内部细节
        final body = isFontRequest(requestUrl)
            ? 'Font not found'
            : 'File not found';
        return WebResourceResponse(
          statusCode: 404,
          reasonPhrase: 'Not Found',
          data: Uint8List.fromList(body.codeUnits),
        );
      }

      final resolved = result.getRight().toNullable()!;
      return WebResourceResponse(
        contentType: resolved.mimeType,
        statusCode: 200,
        reasonPhrase: resolved.fromCache ? 'OK (Cached)' : 'OK',
        data: resolved.bytes,
        headers: _headers,
      );
    } catch (e) {
      // Internal error
      return WebResourceResponse(
        statusCode: 500,
        reasonPhrase: 'Internal Server Error',
        data: Uint8List.fromList('Error: $e'.codeUnits),
      );
    }
  }

  Future<CustomSchemeResponse?> handleRequestWithCustomScheme({
    required String epubPath,
    required String fileHash,
    required WebUri requestUrl,
  }) async {
    try {
      final result = await _resolveResource(epubPath, fileHash, requestUrl);
      if (result.isLeft()) {
        // iOS 通道把真实错误消息直接交给渲染引擎
        final msg = result.getLeft().toNullable()!;
        return CustomSchemeResponse(
          contentType: 'text/plain',
          data: Uint8List.fromList(msg.codeUnits),
        );
      }

      final resolved = result.getRight().toNullable()!;
      return CustomSchemeResponse(
        contentType: resolved.mimeType,
        data: resolved.bytes,
      );
    } catch (e) {
      final errorMessage = 'Error reading file: $e';
      return CustomSchemeResponse(
        contentType: 'text/plain',
        data: Uint8List.fromList(errorMessage.codeUnits),
      );
    }
  }

  /// 两条公开方法共享的资源解析管线：内存缓存 → 字体/书籍读取 → 写入内存缓存。
  /// 改 EPUB 资源读取规则只动这里与 [_readFileFromEpub]，无需同步平台包装层。
  /// Returns Either:
  ///   - Left: error message
  ///   - Right: 解析结果（字节 + MIME + 是否缓存命中）
  Future<Either<String, _ResolvedResource>> _resolveResource(
    String epubPath,
    String fileHash,
    WebUri requestUrl,
  ) async {
    final urlString = requestUrl.toString();

    // 1. 优先从内存缓存中获取资源
    final cached = _getCachedResource(urlString);
    if (cached != null) {
      return right(
        _ResolvedResource(
          bytes: cached.bytes,
          mimeType: cached.mimeType,
          fromCache: true,
        ),
      );
    }

    // 2. 用户导入字体走本地字体目录，其余按 EPUB/TXT 书籍读取
    final Either<String, (Uint8List, String)> result = isFontRequest(requestUrl)
        ? await _readFontFile(requestUrl)
        : await _readFileFromEpub(epubPath, fileHash, requestUrl);

    final data = result.getRight().toNullable();
    if (data == null) {
      return left(result.getLeft().toNullable()!);
    }

    _cacheResource(urlString, data.$1, data.$2);
    return right(
      _ResolvedResource(bytes: data.$1, mimeType: data.$2, fromCache: false),
    );
  }

  /// Read a file from the book container (EPUB ZIP 或 TXT 单文件)
  /// Returns Either:
  ///   - Left: error message
  ///   - Right: (data, mimeType)
  Future<Either<String, (Uint8List, String)>> _readFileFromEpub(
    String epubPath,
    String fileHash,
    WebUri requestUrl,
  ) async {
    final prefix = "/book/$fileHash/";
    if (!requestUrl.path.startsWith(prefix)) {
      return left('Invalid file hash');
    }

    final decodedPath = Uri.decodeFull(requestUrl.path);
    final relativePath = decodedPath.substring(prefix.length);

    final fileRelativePath = relativePath.split('#')[0];

    final fullBookPath = '${AppStorage.documentsPath}$epubPath';

    // TXT 单文件书籍：按 manifest 的字节范围切片并包装为 XHTML
    if (epubPath.endsWith(BookFormat.txt.fileExtension)) {
      return _txtContentService.readChapter(
        txtAbsolutePath: fullBookPath,
        fileHash: fileHash,
        relativePath: fileRelativePath,
      );
    }

    // 所有的 EPUB 文件读取都在 EpubStreamService 的后台 Isolate 中进行
    final result = await _streamService.readFileFromEpub(
      epubPath: fullBookPath,
      targetFilePath: fileRelativePath,
    );

    if (result.isLeft()) {
      return left(result.getLeft().toNullable() ?? 'Error reading file');
    }

    var data = result.getRight().toNullable()!;
    final mimeType = _streamService.getMimeType(fileRelativePath);

    // 书内脚本剥离：TXT 章节内容已整体转义（TxtContentService.buildChapterHtml），
    // 无脚本面；EPUB 的 XHTML/SVG 在供给前剥离 <script> 与 on* 属性。
    // 两条平台通道（handleRequest / handleRequestWithCustomScheme）都经
    // _resolveResource 进入本方法，这里是 EPUB 资源读取规则的唯一改动点
    if (needsScriptStripping(mimeType)) {
      data = Uint8List.fromList(
        utf8.encode(sanitizeBookXhtml(utf8.decode(data, allowMalformed: true))),
      );
    }

    return right((data, mimeType));
  }

  /// Reads a font file from the app's fonts directory.
  /// URL format: book://localhost/fonts/{fileName}
  Future<Either<String, (Uint8List, String)>> _readFontFile(
    WebUri requestUrl,
  ) async {
    const prefix = '/fonts/';
    if (!requestUrl.path.startsWith(prefix)) {
      return left('Invalid font path');
    }
    final fileName = Uri.decodeComponent(
      requestUrl.path.substring(prefix.length),
    );
    if (fileName.isEmpty || fileName.contains('/')) {
      return left('Invalid font file name');
    }
    final filePath = '${AppStorage.documentsPath}fonts/$fileName';

    // 使用 compute 将文件读取操作移至后台线程，避免阻塞主线程
    // 即使是异步的 await file.readAsBytes()，在某些情况下也可能引起卡顿
    try {
      final bytes = await compute(_readFontFileTask, filePath);
      if (bytes == null) {
        return left('Font file not found: $fileName');
      }
      final ext = fileName.toLowerCase().split('.').last;
      final mimeType = _fontMimeTypes[ext] ?? 'application/octet-stream';
      return right((bytes, mimeType));
    } catch (e) {
      return left('Error reading font: $e');
    }
  }

  /// 独立的后台任务函数，用于 compute 调用
  static Future<Uint8List?> _readFontFileTask(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    return await file.readAsBytes();
  }

  static const _fontMimeTypes = {
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
  };

  /// Generate base URL for a chapter
  /// This URL should be used as the baseUrl parameter when loading HTML
  static String getBaseUrl() {
    return '$virtualScheme://$virtualDomain/book/index.html';
  }

  /// Generate full URL for a specific file
  static String getFileUrl(String fileHash, Href href) {
    final url =
        '$virtualScheme://$virtualDomain/book/$fileHash/${href.path}${'#${href.anchor}'}';
    return Uri.encodeFull(url);
  }

  /// Check if a request is for a book chapter: 两种格式共用 `book://` 虚拟域。
  static bool isBookRequest(WebUri requestUrl) {
    return requestUrl.scheme == virtualScheme &&
        requestUrl.host == virtualDomain &&
        requestUrl.path.startsWith('/book/');
  }

  /// Check if a request is for a user-imported font.
  static bool isFontRequest(WebUri requestUrl) {
    return requestUrl.scheme == virtualScheme &&
        requestUrl.host == virtualDomain &&
        requestUrl.path.startsWith('/fonts/');
  }
}
