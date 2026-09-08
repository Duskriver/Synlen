part of '../reader_screen.dart';

mixin _PageNavigationMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  int get currentPageInChapter;
  set currentPageInChapter(int v);

  int get totalPagesInChapter;
  set totalPagesInChapter(int v);

  int get currentSpineItemIndex;

  BookSession get bookSession;

  ReaderRendererController get rendererController;

  // === Cross-mixin: _SpineNavigationMixin ===
  Future<void> nextSpineItem();
  Future<void> previousSpineItem();

  // === Cross-mixin: _ProgressMixin ===
  void updateProgressDebounced();
  void saveProgressDebounced();

  bool get isWebViewLoading;

  /// 由宿主 State 组合出的导航忙态（加载中 / 主题刷新中 / 正在翻章）。
  bool get isNavigationBusy;

  bool get updatingTheme;
  bool get isChangingChapter;

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  bool canPerformPageTurn(bool isNext) {
    if (!mounted || isNavigationBusy) {
      return false;
    }

    final boundary = resolvePageTurnBoundary(
      isNext: isNext,
      currentPage: currentPageInChapter,
      totalPages: totalPagesInChapter,
      currentSpineIndex: currentSpineItemIndex,
      spineLength: bookSession.spine.length,
    );

    switch (boundary) {
      case PageTurnBoundary.ok:
        return true;
      case PageTurnBoundary.firstPageOfBook:
        ToastService.showError(
          AppLocalizations.of(context)!.firstPageOfBook,
          theme: getEpubTheme().themeData,
        );
        return false;
      case PageTurnBoundary.lastPageOfBook:
        ToastService.showError(
          AppLocalizations.of(context)!.lastPageOfBook,
          theme: getEpubTheme().themeData,
        );
        return false;
    }
  }

  Future<void> handlePageTurn(bool isNext) async {
    if (isNext) {
      await nextPage();
    } else {
      await previousPage();
    }
  }

  Future<void> goToPage(int pageIndex) async {
    if (!mounted || isNavigationBusy) {
      return;
    }
    if (pageIndex < 0 || pageIndex >= totalPagesInChapter) return;

    await rendererController.jumpToPage(pageIndex);
    saveProgressDebounced();
  }

  Future<void> nextPage() async {
    final target = pageTurnTargetIndex(
      isNext: true,
      currentPage: currentPageInChapter,
      totalPages: totalPagesInChapter,
    );
    if (target == null) {
      await nextSpineItem();
    } else {
      await goToPage(target);
    }
  }

  Future<void> previousPage() async {
    final target = pageTurnTargetIndex(
      isNext: false,
      currentPage: currentPageInChapter,
      totalPages: totalPagesInChapter,
    );
    if (target == null) {
      await previousSpineItem();
    } else {
      await goToPage(target);
    }
  }
}
