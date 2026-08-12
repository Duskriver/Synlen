import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/data/epub_webview_handler.dart';

void main() {
  group('EpubWebViewHandler URL 工具', () {
    test('getBaseUrl should point at the virtual book index', () {
      expect(
        EpubWebViewHandler.getBaseUrl(),
        'epub://localhost/book/index.html',
      );
    });

    test('getFileUrl should URL-encode the path and keep the anchor', () {
      final url = EpubWebViewHandler.getFileUrl(
        'abc123',
        Href(path: 'chapter 1.xhtml', anchor: 'sec2'),
      );

      expect(url, contains('/book/abc123/'));
      expect(url, contains('%20'));
      expect(url, endsWith('#sec2'));
    });

    test('getFileUrl should keep the default anchor', () {
      final url = EpubWebViewHandler.getFileUrl(
        'abc123',
        Href(path: 'ch.xhtml'),
      );

      expect(url, endsWith('#top'));
    });

    test('getFontUrl should point at the virtual fonts path', () {
      expect(
        EpubWebViewHandler.getFontUrl('song.ttf'),
        'epub://localhost/fonts/song.ttf',
      );
    });

    test('isEpubRequest should only match book paths on the virtual host', () {
      expect(
        EpubWebViewHandler.isEpubRequest(
          WebUri('epub://localhost/book/abc123/ch.xhtml'),
        ),
        isTrue,
      );
      expect(
        EpubWebViewHandler.isEpubRequest(
          WebUri('epub://localhost/fonts/song.ttf'),
        ),
        isFalse,
      );
      expect(
        EpubWebViewHandler.isEpubRequest(WebUri('https://example.com/book/x')),
        isFalse,
      );
    });

    test('isFontRequest should only match font paths on the virtual host', () {
      expect(
        EpubWebViewHandler.isFontRequest(
          WebUri('epub://localhost/fonts/song.ttf'),
        ),
        isTrue,
      );
      expect(
        EpubWebViewHandler.isFontRequest(
          WebUri('epub://localhost/book/abc123/ch.xhtml'),
        ),
        isFalse,
      );
      expect(
        EpubWebViewHandler.isFontRequest(WebUri('https://example.com/fonts/x')),
        isFalse,
      );
    });
  });
}
