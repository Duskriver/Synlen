/// Typed wrapper around every `window.flutter_inappwebview.callHandler` call
export class FlutterBridge {
  static onViewportResize(): void {
    window.flutter_inappwebview.callHandler('onViewportResize');
  }

  static onPageCountReady(pageCount: number): void {
    window.flutter_inappwebview.callHandler('onPageCountReady', pageCount);
  }

  static onPageChanged(pageIndex: number): void {
    window.flutter_inappwebview.callHandler('onPageChanged', pageIndex);
  }

  static onScrollAnchors(anchors: string[]): void {
    window.flutter_inappwebview.callHandler('onScrollAnchors', anchors);
  }

  static onTap(x: number, y: number): void {
    window.flutter_inappwebview.callHandler('onTap', x, y);
  }

  static onLinkTap(href: string, x: number, y: number): void {
    window.flutter_inappwebview.callHandler('onLinkTap', href, x, y);
  }

  static onFootnoteTap(
    innerHtml: string,
    left: number,
    top: number,
    width: number,
    height: number,
    baseUrl: string
  ): void {
    window.flutter_inappwebview.callHandler('onFootnoteTap', innerHtml, left, top, width, height, baseUrl);
  }

  static onImageLongPress(
    src: string,
    x: number,
    y: number,
    width: number,
    height: number
  ): void {
    window.flutter_inappwebview.callHandler('onImageLongPress', src, x, y, width, height);
  }

  /** 矩形使用顶层 WebView 视口的 CSS 像素，已包含章节排版与 iframe 偏移。 */
  static onWordTap(word: string, context: string, x: number, y: number,
    width: number, height: number, requestId: number): void {
    window.flutter_inappwebview.callHandler('onWordTap', word, context, x, y, width, height, requestId);
  }

  static onSentenceSelected(sentence: string): void {
    window.flutter_inappwebview.callHandler('onSentenceSelected', sentence);
  }

  static onEventFinished(token: number): void {
    window.flutter_inappwebview.callHandler('onEventFinished', token);
  }
}
