part of 'reader_renderer.dart';

class ReaderRendererController implements ReaderViewport {
  _ReaderRendererState? _rendererState;

  bool get isAttached => _rendererState != null;

  EpubTheme? get currentTheme => _rendererState?._currentTheme;

  ReaderWebViewController? get webViewController =>
      _rendererState?._webViewController;

  void _attachState(_ReaderRendererState? state) {
    _rendererState = state;
  }

  Future<void> performPreviousPageTurn() async {
    await webViewController?.waitForRender();
    await _rendererState?._performPageTurn(false);
  }

  Future<void> performNextPageTurn() async {
    await webViewController?.waitForRender();
    await _rendererState?._performPageTurn(true);
  }

  @override
  Future<void> jumpToPage(int pageIndex) async {
    await webViewController?.jumpToPage(pageIndex);
  }

  @override
  Future<void> restoreScrollPosition(double ratio) async {
    await webViewController?.restoreScrollPosition(ratio);
  }

  @override
  Future<void> jumpToPreviousChapterLastPage() async {
    final token1 = await webViewController?.jumpToLastPageOfFrame('prev');
    final token2 = await webViewController?.cycleFrames('prev');
    final tokens = [token1, token2].whereType<int>().toList();
    await webViewController?.waitForEvents(tokens);
  }

  @override
  Future<void> jumpToPreviousChapterFirstPage() async {
    final token1 = await webViewController?.jumpToPageFor('prev', 0);
    final token2 = await webViewController?.cycleFrames('prev');
    final tokens = [token1, token2].whereType<int>().toList();
    await webViewController?.waitForEvents(tokens);
  }

  @override
  Future<void> jumpToNextChapter() async {
    final token1 = await webViewController?.jumpToPageFor('next', 0);
    final token2 = await webViewController?.cycleFrames('next');
    final tokens = [token1, token2].whereType<int>().toList();
    await webViewController?.waitForEvents(tokens);
  }

  /// 按预载请求的槽位把章节送进对应的 iframe。
  @override
  Future<int?> preloadChapter(ChapterPreloadRequest request) async {
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
    return await webViewController?.loadFrame(
      frame,
      request.url,
      anchorsJson,
      propertiesJson,
    );
  }

  Future<void> updateTheme(EpubTheme theme) async {
    await _rendererState?._updateTheme(theme);
  }

  @override
  Future<void> waitForEvents(List<int> tokens) async {
    await webViewController?.waitForEvents(tokens);
  }

  Future<void> waitForEvent(int token) async {
    await webViewController?.waitForEvent(token);
  }
}
