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

  Timer? get _saveProgressDebouncer;
  set _saveProgressDebouncer(Timer? v);

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
    _saveProgressDebouncer?.cancel();
    _saveProgressDebouncer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      saveProgress();
    });
  }

  void saveProgress() {
    bookSession.saveProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }
}
