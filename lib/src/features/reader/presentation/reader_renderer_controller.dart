part of 'reader_renderer.dart';

class ReaderRendererController implements ReaderViewport {
  _ReaderRendererState? _rendererState;

  bool get isAttached => _rendererState != null;

  EpubTheme? get currentTheme => _rendererState?._currentTheme;

  ReaderWebViewController? get webViewController =>
      _rendererState?._webViewController;

  ReaderWebViewController get _webView =>
      webViewController ?? (throw StateError('阅读视口尚未就绪'));

  void _attachState(_ReaderRendererState? state) {
    _rendererState = state;
  }

  Future<void> performPreviousPageTurn() async {
    await _rendererState?._performPageTurn(false);
  }

  Future<void> performNextPageTurn() async {
    await _rendererState?._performPageTurn(true);
  }

  @override
  Future<void> jumpToPage(int pageIndex) async {
    await _webView.jumpToPage(pageIndex);
  }

  @override
  Future<void> restoreScrollPosition(double ratio) async {
    await _webView.restoreScrollPosition(ratio);
  }

  @override
  Future<void> jumpToPreviousChapterLastPage() => Future.wait([
    _webView.jumpToLastPageOfFrame('prev'),
    _webView.cycleFrames('prev'),
  ]);

  @override
  Future<void> jumpToPreviousChapterFirstPage() => Future.wait([
    _webView.jumpToPageFor('prev', 0),
    _webView.cycleFrames('prev'),
  ]);

  @override
  Future<void> jumpToNextChapter() => Future.wait([
    _webView.jumpToPageFor('next', 0),
    _webView.cycleFrames('next'),
  ]);

  /// 按预载请求的槽位把章节送进对应的 iframe。
  Future<void> _preloadChapter(ChapterPreloadRequest request) async {
    final frame = switch (request.slot) {
      ChapterSlot.current => 'curr',
      ChapterSlot.previous => 'prev',
      ChapterSlot.next => 'next',
    };
    final anchorsJson = jsonEncode(request.anchors);
    final propertiesList = List<String>.from(
      request.properties?.split(' ') ?? [],
    );
    final propertiesJson = jsonEncode(
      propertiesList.map((p) => p.replaceAll(':', '-COLON-')).toList(),
    );
    return await _webView.loadFrame(
      frame,
      request.url,
      anchorsJson,
      propertiesJson,
    );
  }

  @override
  Future<void> updateTheme(EpubTheme theme) async {
    final state = _rendererState;
    if (state == null) throw StateError('阅读视口尚未就绪');
    await state._updateTheme(theme);
  }

  @override
  Future<void> prepareChapters(List<ChapterPreloadRequest> requests) async {
    final controller = webViewController;
    if (controller == null) throw StateError('阅读视口尚未就绪');
    await Future.wait(requests.map(_preloadChapter));
  }
}
