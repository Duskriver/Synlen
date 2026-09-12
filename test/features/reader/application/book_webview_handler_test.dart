import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/book_webview_handler.dart';
import 'package:synlen/src/features/reader/data/services/epub_backend.dart';
import 'package:synlen/src/features/reader/data/services/epub_stream_service.dart';
import 'package:synlen/src/features/reader/data/services/txt_content_service.dart';
import 'package:synlen/src/features/reader/data/services/txt_spine_source.dart';

/// 记录调用序列的 Rust 后端 fake（与 epub_stream_service_test 同型）。
class _FakeBackend implements EpubBackend {
  final List<String> calls = [];
  final Map<String, Uint8List> files = {};

  @override
  Future<void> load(String epubPath) async => calls.add('load:$epubPath');

  @override
  Future<Uint8List?> readFile({
    required String epubPath,
    required String filePath,
  }) async {
    calls.add('read:$filePath');
    return files[filePath];
  }

  @override
  Future<void> close(String epubPath) async => calls.add('close:$epubPath');
}

/// 管线测试不触碰 TXT 路径，spine 来源恒为空即可。
class _NullSpineSource implements TxtSpineSource {
  @override
  Future<List<SpineItem>?> spineFor(String fileHash) async => null;
}

void main() {
  group('BookWebViewHandler URL 工具', () {
    test('getBaseUrl should point at the virtual book index', () {
      expect(
        BookWebViewHandler.getBaseUrl(),
        'book://localhost/book/index.html',
      );
    });

    test('getFileUrl should URL-encode the path and keep the anchor', () {
      final url = BookWebViewHandler.getFileUrl(
        'abc123',
        Href(path: 'chapter 1.xhtml', anchor: 'sec2'),
      );

      expect(url, contains('/book/abc123/'));
      expect(url, contains('%20'));
      expect(url, endsWith('#sec2'));
    });

    test('getFileUrl should keep the default anchor', () {
      final url = BookWebViewHandler.getFileUrl(
        'abc123',
        Href(path: 'ch.xhtml'),
      );

      expect(url, endsWith('#top'));
    });

    test('isBookRequest should only match book paths on the virtual host', () {
      expect(
        BookWebViewHandler.isBookRequest(
          WebUri('book://localhost/book/abc123/ch.xhtml'),
        ),
        isTrue,
      );
      expect(
        BookWebViewHandler.isBookRequest(
          WebUri('book://localhost/fonts/song.ttf'),
        ),
        isFalse,
      );
      expect(
        BookWebViewHandler.isBookRequest(WebUri('https://example.com/book/x')),
        isFalse,
      );
    });

    test('isFontRequest should only match font paths on the virtual host', () {
      expect(
        BookWebViewHandler.isFontRequest(
          WebUri('book://localhost/fonts/song.ttf'),
        ),
        isTrue,
      );
      expect(
        BookWebViewHandler.isFontRequest(
          WebUri('book://localhost/book/abc123/ch.xhtml'),
        ),
        isFalse,
      );
      expect(
        BookWebViewHandler.isFontRequest(WebUri('https://example.com/fonts/x')),
        isFalse,
      );
    });
  });

  group('BookWebViewHandler 资源管线', () {
    const epubPath = 'books/book-a.epub';
    const fileHash = 'abc123';

    late Directory tempDir;
    late _FakeBackend backend;
    late BookWebViewHandler handler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'synlen_webview_handler_test_',
      );
      AppStorage.initForTesting(documentsPath: tempDir.path);
      backend = _FakeBackend();
      handler = BookWebViewHandler(
        streamService: EpubStreamService(backend: backend),
        txtContentService: TxtContentService(spineSource: _NullSpineSource()),
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('缓存命中时不重复读取文件', () async {
      backend.files['ch1.xhtml'] = Uint8List.fromList([1, 2, 3]);
      final url = WebUri('book://localhost/book/abc123/ch1.xhtml');

      final first = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );
      final second = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );

      expect(first!.statusCode, 200);
      expect(first.reasonPhrase, 'OK');
      expect(second!.statusCode, 200);
      expect(second.reasonPhrase, 'OK (Cached)');
      expect(backend.calls.where((c) => c.startsWith('read:')), hasLength(1));
    });

    test('字体请求走本地字体目录，不触碰 EPUB', () async {
      final fontsDir = Directory('${tempDir.path}/fonts')..createSync();
      final fontBytes = Uint8List.fromList([0, 1, 2, 3]);
      File('${fontsDir.path}/song.ttf').writeAsBytesSync(fontBytes);

      final response = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: WebUri('book://localhost/fonts/song.ttf'),
      );

      expect(response!.statusCode, 200);
      expect(response.contentType, 'font/ttf');
      expect(response.data, fontBytes);
      expect(backend.calls, isEmpty);
    });

    test('字体缺失时 Android 回退通用文案，iOS 暴露真实错误消息', () async {
      final url = WebUri('book://localhost/fonts/missing.ttf');

      final android = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );
      final ios = await handler.handleRequestWithCustomScheme(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );

      expect(android!.statusCode, 404);
      expect(String.fromCharCodes(android.data!), 'Font not found');
      expect(ios!.contentType, 'text/plain');
      expect(
        String.fromCharCodes(ios.data),
        contains('Font file not found: missing.ttf'),
      );
    });

    test('EPUB 资源成功时两通道都返回字节与 MIME', () async {
      backend.files['style.css'] = Uint8List.fromList([9, 8, 7]);
      final url = WebUri('book://localhost/book/abc123/style.css');

      final android = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );
      final ios = await handler.handleRequestWithCustomScheme(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );

      expect(android!.statusCode, 200);
      expect(android.contentType, 'text/css');
      expect(android.data, backend.files['style.css']);
      expect(ios!.contentType, 'text/css');
      expect(ios.data, backend.files['style.css']);
    });

    test('EPUB 资源不存在时 Android 返回 404 通用文案，iOS 暴露真实错误消息', () async {
      final url = WebUri('book://localhost/book/abc123/missing.xhtml');

      final android = await handler.handleRequest(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );
      final ios = await handler.handleRequestWithCustomScheme(
        epubPath: epubPath,
        fileHash: fileHash,
        requestUrl: url,
      );

      expect(android!.statusCode, 404);
      expect(android.reasonPhrase, 'Not Found');
      expect(String.fromCharCodes(android.data!), 'File not found');
      expect(ios!.contentType, 'text/plain');
      expect(
        String.fromCharCodes(ios.data),
        contains('File not found: missing.xhtml'),
      );
    });
  });
}
