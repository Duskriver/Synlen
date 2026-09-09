import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/book_webview_handler.dart';

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

    test('getFontUrl should point at the virtual fonts path', () {
      expect(
        BookWebViewHandler.getFontUrl('song.ttf'),
        'book://localhost/fonts/song.ttf',
      );
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
}
