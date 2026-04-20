import 'dart:io';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/data/services/epub_stream_service.dart';

class _CachedResource {
  final Uint8List bytes;
  final String mimeType;

  const _CachedResource({required this.bytes, required this.mimeType});

  int get sizeInBytes => bytes.lengthInBytes;
}

/// WebView request handler for streaming EPUB content
/// Intercepts requests to virtual domain and serves files from compressed EPUB
class EpubWebViewHandler {
  final EpubStreamService _streamService;

  /// 内存缓存，用于存储已加载的资源（CSS, 图片, 字体等）。
  /// 使用 LRU + 总字节数上限，避免长时间阅读时无限增长。
  static const int _maxCachedEntries = 256;
  static const int _maxCacheBytes = 24 * 1024 * 1024;
  static const int _maxCacheableEntryBytes = 2 * 1024 * 1024;
  final LinkedHashMap<String, _CachedResource> _resourceCache = LinkedHashMap();
  int _cachedBytes = 0;

  /// Virtual domain for EPUB content
  /// Format: epub://localhost/book/{fileHash}/{filePath}
  static const String virtualDomain = 'localhost';
  static const String virtualScheme = 'epub';
  static const _headers = {'Cache-Control': 'public, max-age=31536000'};

  EpubWebViewHandler({required EpubStreamService streamService})
    : _streamService = streamService;

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
      final urlString = requestUrl.toString();

      // 1. 优先从内存缓存中获取资源
      final cached = _getCachedResource(urlString);
      if (cached != null) {
        return WebResourceResponse(
          contentType: cached.mimeType,
          statusCode: 200,
          reasonPhrase: 'OK (Cached)',
          data: cached.bytes,
          headers: _headers,
        );
      }

      // Serve user-imported fonts.
      if (isFontRequest(requestUrl)) {
        final result = await _readFontFile(requestUrl);
        if (result.isLeft()) {
          return WebResourceResponse(
            statusCode: 404,
            reasonPhrase: 'Not Found',
            data: Uint8List.fromList('Font not found'.codeUnits),
          );
        }
        final cachedData = result.getRight().toNullable()!;
        _cacheResource(urlString, cachedData.$1, cachedData.$2);

        return WebResourceResponse(
          contentType: cachedData.$2,
          statusCode: 200,
          reasonPhrase: 'OK',
          data: cachedData.$1,
          headers: _headers,
        );
      }

      // Read file from EPUB
      final result = await _readFileFromEpub(epubPath, fileHash, requestUrl);

      if (result.isLeft()) {
        // File not found or error
        return WebResourceResponse(
          statusCode: 404,
          reasonPhrase: 'Not Found',
          data: Uint8List.fromList('File not found'.codeUnits),
        );
      }

      final dataPair = result.getRight().toNullable()!;
      _cacheResource(urlString, dataPair.$1, dataPair.$2);

      // Return the file content
      return WebResourceResponse(
        contentType: dataPair.$2,
        statusCode: 200,
        reasonPhrase: 'OK',
        data: dataPair.$1,
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
      final urlString = requestUrl.toString();

      // 1. 优先从内存缓存中获取资源
      final cached = _getCachedResource(urlString);
      if (cached != null) {
        return CustomSchemeResponse(
          contentType: cached.mimeType,
          data: cached.bytes,
        );
      }

      // Serve user-imported fonts.
      if (isFontRequest(requestUrl)) {
        final result = await _readFontFile(requestUrl);
        if (result.isLeft()) {
          final msg = result.getLeft().toNullable()!;
          return CustomSchemeResponse(
            contentType: 'text/plain',
            data: Uint8List.fromList(msg.codeUnits),
          );
        }
        final cachedData = result.getRight().toNullable()!;
        _cacheResource(urlString, cachedData.$1, cachedData.$2);
        return CustomSchemeResponse(
          contentType: cachedData.$2,
          data: cachedData.$1,
        );
      }

      final result = await _readFileFromEpub(epubPath, fileHash, requestUrl);

      if (result.isLeft()) {
        final errorMessage = result.getLeft().toNullable()!;
        return CustomSchemeResponse(
          contentType: 'text/plain',
          data: Uint8List.fromList(errorMessage.codeUnits),
        );
      }

      final dataPair = result.getRight().toNullable()!;
      _cacheResource(urlString, dataPair.$1, dataPair.$2);

      return CustomSchemeResponse(contentType: dataPair.$2, data: dataPair.$1);
    } catch (e) {
      final errorMessage = 'Error reading file: $e';
      return CustomSchemeResponse(
        contentType: 'text/plain',
        data: Uint8List.fromList(errorMessage.codeUnits),
      );
    }
  }

  /// Read a file from an EPUB
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

    final fullEpubPath = '${AppStorage.documentsPath}$epubPath';

    // 所有的 EPUB 文件读取都在 EpubStreamService 的后台 Isolate 中进行
    final result = await _streamService.readFileFromEpub(
      epubPath: fullEpubPath,
      targetFilePath: fileRelativePath,
    );

    if (result.isLeft()) {
      return left(result.getLeft().toNullable() ?? 'Error reading file');
    }

    final data = result.getRight().toNullable()!;
    final mimeType = _streamService.getMimeType(fileRelativePath);

    return right((data, mimeType));
  }

  /// Reads a font file from the app's fonts directory.
  /// URL format: epub://localhost/fonts/{fileName}
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

  /// Generate URL for a user-imported font file.
  /// Format: epub://localhost/fonts/{fileName}
  static String getFontUrl(String fileName) {
    return '$virtualScheme://$virtualDomain/fonts/$fileName';
  }

  /// Check if a request is for an EPUB file
  static bool isEpubRequest(WebUri requestUrl) {
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
