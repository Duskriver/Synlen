part of '../reader_screen.dart';

mixin _ProgressMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  int get totalPagesInChapter;

  int get currentPageInChapter;

  int get currentSpineItemIndex;

  BookSession get bookSession;

  bool get isWebViewLoading;

  String get displayProgress;
  set displayProgress(String v);

  Timer? get progressDebouncer;
  set progressDebouncer(Timer? v);

  ReadingProgressController get progressController;

  bool get updatingTheme;
  bool get isChangingChapter;

  void updateProgressDebounced() {
    progressDebouncer?.cancel();
    progressDebouncer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (isWebViewLoading) return;

      final pageInChapterStr =
          '${currentPageInChapter + 1}/$totalPagesInChapter';

      if (displayProgress != pageInChapterStr) {
        displayProgress = pageInChapterStr;
      }
    });
  }

  void saveProgressDebounced() {
    if (!mounted) return;
    progressController.record(
      (
        chapterIndex: currentSpineItemIndex,
        pageIndex: currentPageInChapter,
        pageCount: totalPagesInChapter,
      ),
      isReady:
          bookSession.isLoaded &&
          currentSpineItemIndex < bookSession.spine.length &&
          !isWebViewLoading &&
          !updatingTheme &&
          !isChangingChapter,
    );
  }

  Future<bool> saveProgress() {
    saveProgressDebounced();
    return progressController.flush();
  }
}
