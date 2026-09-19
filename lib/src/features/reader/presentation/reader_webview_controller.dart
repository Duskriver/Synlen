part of 'reader_webview.dart';

/// Controller for ReaderWebView that provides methods to control the WebView
class ReaderWebViewController {
  _ReaderWebViewState? _webViewState;

  _ReaderWebViewState get _state =>
      _webViewState ?? (throw StateError('阅读视口尚未就绪'));

  bool get isAttached => _webViewState != null;

  void _attachState(_ReaderWebViewState? state) {
    _webViewState = state;
  }

  // JavaScript wrapper methods
  Future<void> jumpToLastPageOfFrame(String frame) async {
    return await _state._jumpToLastPageOfFrame(frame);
  }

  Future<void> cycleFrames(String direction) async {
    return await _state._cycleFrames(direction);
  }

  Future<void> jumpToPageFor(String frame, int pageIndex) async {
    return await _state._jumpToPageFor(frame, pageIndex);
  }

  Future<void> loadFrame(
    String frame,
    String url,
    String anchors,
    String properties,
  ) async {
    return await _state._loadFrame(frame, url, anchors, properties);
  }

  Future<void> jumpToPage(int pageIndex) async {
    await _state._jumpToPage(pageIndex);
  }

  Future<void> restoreScrollPosition(double ratio) async {
    await _state._restoreScrollPosition(ratio);
  }

  Future<void> checkLongPressElementAt(double x, double y) async {
    await _state._checkLongPressElementAt(x, y);
  }

  Future<void> checkTapElementAt(double x, double y) async {
    await _state._checkTapElementAt(x, y);
  }

  Future<ui.Image?> takeScreenshot() async {
    return await _state._takeScreenshot();
  }

  Future<void> waitForRender() async {
    await _state._waitForRender();
  }

  Future<void> updateTheme(EpubTheme theme) async {
    await _state._updateTheme(theme);
  }
}

/// Callbacks for WebView events
class ReaderWebViewCallbacks {
  final Function() onInitialized;
  final VoidCallback? onViewportResize;
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
    this.onViewportResize,
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
      onViewportResize: onViewportResize,
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
