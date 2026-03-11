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

  /// 用于保存进度的防抖计时器，避免频繁的数据库写入
  Timer? get _saveProgressDebouncer;
  set _saveProgressDebouncer(Timer? v);

  double calculateProgressRatio() {
    if (totalPagesInChapter == 0) return 0.0;
    final pageProgress = (currentPageInChapter + 1) / totalPagesInChapter;
    final chapterProgress = currentSpineItemIndex / bookSession.spine.length;
    return (chapterProgress + pageProgress / bookSession.spine.length).clamp(
      0.0,
      1.0,
    );
  }

  void updateProgressDebounced() {
    progressDebouncer?.cancel();
    progressDebouncer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (isWebViewLoading) return;

      final ratio = calculateProgressRatio();
      final newProgress = '${(ratio * 100.0).toStringAsFixed(2)}%';

      if (displayProgress != newProgress) {
        displayProgress = newProgress;
      }
    });
  }

  /// 带防抖的保存进度方法，防止用户快速翻页时频繁触发数据库写操作导致主线程卡顿
  void saveProgressDebounced() {
    _saveProgressDebouncer?.cancel();
    _saveProgressDebouncer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      saveProgress();
    });
  }

  /// 实际执行数据库保存操作
  Future<void> saveProgress() async {
    // 所有的数据库 I/O 操作虽然是异步的，但高频率触发仍会占用 CPU 资源
    await bookSession.saveProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }
}
