part of 'reader_webview.dart';

/// Controller for ReaderWebView that provides methods to control the WebView
class ReaderWebViewController {
  _ReaderWebViewState? _webViewState;

  bool get isAttached => _webViewState != null;

  void _attachState(_ReaderWebViewState? state) {
    _webViewState = state;
  }

  // JavaScript wrapper methods
  Future<int?> jumpToLastPageOfFrame(String frame) async {
    return await _webViewState?._jumpToLastPageOfFrame(frame);
  }

  Future<int?> cycleFrames(String direction) async {
    return await _webViewState?._cycleFrames(direction);
  }

  Future<int?> jumpToPageFor(String frame, int pageIndex) async {
    return await _webViewState?._jumpToPageFor(frame, pageIndex);
  }

  Future<int?> loadFrame(
    String frame,
    String url,
    String anchors,
    String properties,
  ) async {
    return await _webViewState?._loadFrame(frame, url, anchors, properties);
  }

  Future<void> jumpToPage(int pageIndex) async {
    await _webViewState?._jumpToPage(pageIndex);
  }

  Future<void> restoreScrollPosition(double ratio) async {
    await _webViewState?._restoreScrollPosition(ratio);
  }

  Future<void> checkLongPressElementAt(double x, double y) async {
    await _webViewState?._checkLongPressElementAt(x, y);
  }

  Future<void> checkTapElementAt(double x, double y) async {
    await _webViewState?._checkTapElementAt(x, y);
  }

  Future<ui.Image?> takeScreenshot() async {
    return await _webViewState?._takeScreenshot();
  }

  Future<void> waitForRender() async {
    await _webViewState?._waitForRender();
  }

  Future<void> updateTheme(EpubTheme theme) async {
    await _webViewState?._updateTheme(theme);
  }

  Future<void> waitForEvent(int token, [int timeoutMs = 10000]) async {
    await _webViewState?._bridge.waitForEvent(token, timeoutMs);
  }

  Future<void> waitForEvents(List<int> tokens, [int timeoutMs = 10000]) async {
    await _webViewState?._bridge.waitForEvents(tokens, timeoutMs);
  }
}

/// Callbacks for WebView events
class ReaderWebViewCallbacks {
  final Function() onInitialized;
  final Function(int totalPages) onPageCountReady;
  final Function(int pageIndex) onPageChanged;
  final Function(List<String> anchors) onScrollAnchors;
  final Function(String imageUrl, Rect rect) onImageLongPress;
  final Function(double x, double y) onTap;
  final Function(String innerHtml, Rect rect, String baseUrl) onFootnoteTap;
  final Function(String url) onLinkTap;
  final bool Function(String url) shouldHandleLinkTap;
  final Function(String word, String context) onWordTap;
  final Function(String sentence) onSentenceSelected;

  const ReaderWebViewCallbacks({
    required this.onInitialized,
    required this.onPageCountReady,
    required this.onPageChanged,
    required this.onScrollAnchors,
    required this.onImageLongPress,
    required this.onTap,
    required this.onFootnoteTap,
    required this.onLinkTap,
    required this.shouldHandleLinkTap,
    required this.onWordTap,
    required this.onSentenceSelected,
  });

  /// 替换区域点击回调：渲染器要接管点击（翻页 / 呼出控制条），
  /// 其余回调保持不变。
  ReaderWebViewCallbacks withTap(Function(double x, double y) onTap) {
    return ReaderWebViewCallbacks(
      onInitialized: onInitialized,
      onPageCountReady: onPageCountReady,
      onPageChanged: onPageChanged,
      onScrollAnchors: onScrollAnchors,
      onImageLongPress: onImageLongPress,
      onTap: onTap,
      onFootnoteTap: onFootnoteTap,
      onLinkTap: onLinkTap,
      shouldHandleLinkTap: shouldHandleLinkTap,
      onWordTap: onWordTap,
      onSentenceSelected: onSentenceSelected,
    );
  }
}
