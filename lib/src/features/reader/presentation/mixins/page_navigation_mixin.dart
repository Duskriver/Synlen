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
  bool get updatingTheme;
  bool get isChangingChapter;

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  bool canPerformPageTurn(bool isNext) {
    if (!mounted || isWebViewLoading || updatingTheme || isChangingChapter) {
      return false;
    }
    if (isNext) {
      if (currentPageInChapter >= totalPagesInChapter - 1 &&
          currentSpineItemIndex >= bookSession.spine.length - 1) {
        ToastService.showError(
          AppLocalizations.of(context)!.lastPageOfBook,
          theme: getEpubTheme().themeData,
        );
        return false;
      }
    } else {
      if (currentPageInChapter <= 0 && currentSpineItemIndex <= 0) {
        ToastService.showError(
          AppLocalizations.of(context)!.firstPageOfBook,
          theme: getEpubTheme().themeData,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> handlePageTurn(bool isNext) async {
    if (isNext) {
      await nextPage();
    } else {
      await previousPage();
    }
  }

  Future<void> goToPage(int pageIndex) async {
    if (!mounted || isWebViewLoading || updatingTheme || isChangingChapter) {
      return;
    }
    if (pageIndex < 0 || pageIndex >= totalPagesInChapter) return;

    await rendererController.jumpToPage(pageIndex);
    saveProgressDebounced();
  }

  Future<void> nextPage() async {
    if (currentPageInChapter < totalPagesInChapter - 1) {
      await goToPage(currentPageInChapter + 1);
    } else {
      await nextSpineItem();
    }
  }

  Future<void> previousPage() async {
    if (currentPageInChapter > 0) {
      await goToPage(currentPageInChapter - 1);
    } else {
      await previousSpineItem();
    }
  }
}
