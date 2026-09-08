part of '../reader_screen.dart';

mixin _SpineNavigationMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  BookSession get bookSession;

  ReaderRendererController get rendererController;

  bool get isWebViewLoading;
  set isWebViewLoading(bool v);

  int get currentSpineItemIndex;
  set currentSpineItemIndex(int v);

  int get currentPageInChapter;
  set currentPageInChapter(int v);

  // === Cross-mixin: _ProgressMixin ===
  void updateProgressDebounced();
  void saveProgressDebounced();

  /// 由宿主 State 组合出的导航忙态（加载中 / 主题刷新中 / 正在翻章）。
  bool get isNavigationBusy;

  bool get updatingTheme;
  bool get isChangingChapter;
  set isChangingChapter(bool value);
  set totalPagesInChapter(int value);

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();
  void refreshActiveTocState();

  void handleScrollAnchors(List<String> anchorIds) {
    bookSession.updateActiveAnchors(anchorIds);
    refreshActiveTocState();
  }

  Future<void> loadCarousel({
    String anchor = 'top',
    int? overrideSpineIndex,
    double? restoreScrollRatio,
  }) async {
    if (!mounted || bookSession.spine.isEmpty) return;
    totalPagesInChapter = 0;
    if (mounted) {
      setState(() {
        isWebViewLoading = true;
      });
    }

    if (overrideSpineIndex != null &&
        overrideSpineIndex >= 0 &&
        overrideSpineIndex < bookSession.spine.length) {
      currentSpineItemIndex = overrideSpineIndex;
      refreshActiveTocState();
    }
    final tokensForWait = <int>[];
    for (final request in planChapterPreload(
      bookSession,
      index: currentSpineItemIndex,
      anchor: anchor,
    )) {
      final token = switch (request.slot) {
        ChapterSlot.current => await rendererController.preloadCurrentChapter(
          request.url,
          request.anchors,
          request.properties,
        ),
        ChapterSlot.previous => await rendererController.preloadPreviousChapter(
          request.url,
          request.anchors,
          request.properties,
        ),
        ChapterSlot.next => await rendererController.preloadNextChapter(
          request.url,
          request.anchors,
          request.properties,
        ),
      };
      if (token != null) tokensForWait.add(token);
    }

    await rendererController.waitForEvents(tokensForWait);

    if (!mounted) {
      return;
    }

    if (restoreScrollRatio != null) {
      await rendererController.restoreScrollPosition(restoreScrollRatio);
    }

    await Future.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }
    setState(() {
      isWebViewLoading = false;
    });
    updateProgressDebounced();
    saveProgressDebounced();
  }

  Future<void> preloadNextOf(int currentIndex) async {
    final request = planNeighbourPreload(
      bookSession,
      index: currentIndex,
      forward: true,
    );
    if (request == null) return;
    await rendererController.preloadNextChapter(
      request.url,
      request.anchors,
      request.properties,
    );
  }

  Future<void> preloadPreviousOf(int currentIndex) async {
    final request = planNeighbourPreload(
      bookSession,
      index: currentIndex,
      forward: false,
    );
    if (request == null) return;
    await rendererController.preloadPreviousChapter(
      request.url,
      request.anchors,
      request.properties,
    );
  }

  Future<void> navigateToSpineItem(int index, [String anchor = 'top']) async {
    if (!mounted || isNavigationBusy) {
      return;
    }
    if (index < 0 || index >= bookSession.spine.length) return;

    currentSpineItemIndex = index;
    currentPageInChapter = 0;
    refreshActiveTocState();
    updateProgressDebounced();

    await loadCarousel(anchor: anchor);
  }

  Future<void> previousSpineItem() async {
    if (!mounted || isNavigationBusy) {
      return;
    }
    if (currentSpineItemIndex <= 0) {
      ToastService.showError(
        AppLocalizations.of(context)!.firstChapterOfBook,
        theme: getEpubTheme().themeData,
      );
      return;
    }

    isChangingChapter = true;
    totalPagesInChapter = 0;
    await rendererController.jumpToPreviousChapterLastPage();
    if (!mounted) return;

    currentSpineItemIndex--;
    isChangingChapter = false;
    refreshActiveTocState();

    preloadPreviousOf(currentSpineItemIndex);
    saveProgressDebounced();
  }

  Future<void> previousSpineItemFirstPage() async {
    if (!mounted || isNavigationBusy) {
      return;
    }
    if (currentSpineItemIndex <= 0) {
      ToastService.showError(
        AppLocalizations.of(context)!.firstChapterOfBook,
        theme: getEpubTheme().themeData,
      );
      return;
    }

    isChangingChapter = true;
    totalPagesInChapter = 0;
    await rendererController.jumpToPreviousChapterFirstPage();
    if (!mounted) return;

    currentSpineItemIndex--;
    isChangingChapter = false;
    currentPageInChapter = 0;
    refreshActiveTocState();
    updateProgressDebounced();

    preloadPreviousOf(currentSpineItemIndex);
    saveProgressDebounced();
  }

  Future<void> nextSpineItem() async {
    if (!mounted || isNavigationBusy) {
      return;
    }
    if (currentSpineItemIndex >= bookSession.spine.length - 1) {
      ToastService.showError(
        AppLocalizations.of(context)!.lastChapterOfBook,
        theme: getEpubTheme().themeData,
      );
      return;
    }

    isChangingChapter = true;
    totalPagesInChapter = 0;
    await rendererController.jumpToNextChapter();
    if (!mounted) return;

    currentSpineItemIndex++;
    isChangingChapter = false;
    currentPageInChapter = 0;
    refreshActiveTocState();
    updateProgressDebounced();

    preloadNextOf(currentSpineItemIndex);
    saveProgressDebounced();
  }

  Future<void> navigateToTocItem(TocItem item) async {
    final targetHref = bookSession.findFirstValidHref(item);

    if (targetHref == null) {
      ToastService.showError(
        AppLocalizations.of(context)!.chapterHasNoContent,
        theme: getEpubTheme().themeData,
      );
      return;
    }

    final index = bookSession.findSpineIndexForTocItem(item);

    if (index != null) {
      await navigateToSpineItem(index, targetHref.anchor);
    } else {
      ToastService.showError(
        AppLocalizations.of(context)!.chapterNotFoundInSpine,
        theme: getEpubTheme().themeData,
      );
      appLogger.w(
        'Warning: Chapter with href ${targetHref.path} not found in spine.',
      );
    }
  }

  Future<void> navigateToFirstTocItemFirstPage() async {
    navigateToSpineItem(0, 'top');
  }

  Set<TocItem> resolveActiveItems() {
    return bookSession.resolveActiveItems(currentSpineItemIndex);
  }
}
