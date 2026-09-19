import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/app_logger.dart';
import '../../library/domain/book_manifest.dart';
import '../domain/epub_theme.dart';
import 'book_session.dart';
import 'reader_navigator.dart';
import 'reader_viewport.dart';
import 'reading_progress_controller.dart';

enum ReaderFailure { bookNotFound, load, render, progress }

/// 一次阅读的编排与资源所有者；关闭后拒绝新请求并忽略迟到结果。
class ReaderWorkflow {
  ReaderWorkflow({
    required this.book,
    required ReaderViewport viewport,
    Duration progressDebounce = const Duration(seconds: 1),
    Duration themeDebounce = const Duration(milliseconds: 200),
    Duration settleDelay = const Duration(milliseconds: 30),
  }) : _viewport = viewport,
       _themeDebounce = themeDebounce,
       navigator = ReaderNavigator(
         session: book,
         viewport: viewport,
         settleDelay: settleDelay,
       ) {
    _progress = ReadingProgressController(
      save: book.saveProgress,
      debounce: progressDebounce,
      onSaveFailed: () => _fail(ReaderFailure.progress),
    );
    navigator.state.addListener(_recordProgress);
  }

  final BookSession book;
  final ReaderNavigator navigator;
  final ReaderViewport _viewport;
  final Duration _themeDebounce;
  late final ReadingProgressController _progress;
  final ValueNotifier<ReaderFailure?> failure = ValueNotifier(null);
  Timer? _themeTimer;
  EpubTheme? _pendingTheme;
  EpubTheme? _appliedTheme;
  bool _forceTheme = false;
  Future<void>? _themeTask;
  Future<ReaderNavOutcome>? _navigation;
  Future<bool>? _closing;
  bool _closed = false;
  bool _initialized = false;
  bool _renderHealthy = false;

  Future<bool> open() async {
    if (_closed) return false;
    try {
      final loaded = await book.loadBook();
      if (_closed) return false;
      if (!loaded) {
        _fail(ReaderFailure.bookNotFound);
        return false;
      }
      navigator.initializePosition();
      return true;
    } catch (error, stack) {
      _fail(ReaderFailure.load, error, stack);
      return false;
    }
  }

  /// WebView 就绪后只恢复一次位置，书目加载阶段不调用尚未挂载的视口。
  Future<ReaderNavOutcome> initializeRenderer({EpubTheme? theme}) async {
    if (_closed || _initialized) return ReaderNavOutcome.ignored;
    await _themeTask;
    if (_closed || _initialized) return ReaderNavOutcome.ignored;
    return _run(() async {
      _initialized = true;
      _appliedTheme = theme;
      await navigator.load(restoreScrollRatio: book.initialScrollPosition);
      return ReaderNavOutcome.moved;
    });
  }

  Future<ReaderNavOutcome> goToChapter(int index, {String anchor = 'top'}) =>
      _run(() => navigator.goToChapter(index, anchor: anchor));
  Future<ReaderNavOutcome> goToTocItem(TocItem item) =>
      _run(() => navigator.goToTocItem(item));
  Future<ReaderNavOutcome> goToPage(int index) =>
      _run(() => navigator.goToPage(index));
  Future<ReaderNavOutcome> turnPage(bool next) =>
      _run(() => navigator.turnPage(next));
  Future<ReaderNavOutcome> nextChapter() => _run(navigator.nextChapter);
  Future<ReaderNavOutcome> previousChapter() =>
      _run(navigator.previousChapterFirstPage);

  Future<ReaderNavOutcome> followInternalLink(String url) {
    final index = book.findSpineIndexByUrl(url);
    if (index == null) return Future.value(ReaderNavOutcome.tocItemNotInSpine);
    final fragment = Uri.parse(url).fragment;
    return goToChapter(index, anchor: fragment.isEmpty ? 'top' : fragment);
  }

  Future<ReaderNavOutcome> _run(
    Future<ReaderNavOutcome> Function() action,
  ) async {
    if (_closed || _navigation != null || _themeTask != null) {
      return ReaderNavOutcome.ignored;
    }
    _renderHealthy = false;
    final task = _perform(action);
    _navigation = task;
    try {
      return await task;
    } finally {
      _navigation = null;
      if (!_closed) {
        _recordProgress();
        if (_pendingTheme != null && _themeTimer?.isActive != true) {
          _startThemeUpdate();
        }
      }
    }
  }

  Future<ReaderNavOutcome> _perform(
    Future<ReaderNavOutcome> Function() action,
  ) async {
    try {
      final outcome = await action();
      if (_closed) return ReaderNavOutcome.ignored;
      _renderHealthy = true;
      if (failure.value == ReaderFailure.render) failure.value = null;
      return outcome;
    } catch (error, stack) {
      _fail(ReaderFailure.render, error, stack);
      return ReaderNavOutcome.ignored;
    }
  }

  /// 展示层提交包含动画或命中测试的渲染动作，错误统一转成阅读状态。
  Future<void> renderInteraction(Future<void> Function() action) async {
    if (_closed) return;
    try {
      await action();
    } catch (error, stack) {
      _fail(ReaderFailure.render, error, stack);
    }
  }

  void reportPageCount(int count) {
    if (!_closed) navigator.reportPageCount(count);
  }

  void reportPageIndex(int index) {
    if (!_closed) navigator.reportPageIndex(index);
  }

  /// 连续设置变更合并为最后一份主题；已开始的排版完成后再应用新主题。
  void requestTheme(
    EpubTheme theme, {
    bool debounce = false,
    bool force = false,
  }) {
    if (_closed) return;
    _forceTheme = _forceTheme || force;
    _pendingTheme = theme;
    _themeTimer?.cancel();
    if (debounce) {
      _themeTimer = Timer(_themeDebounce, _startThemeUpdate);
    } else {
      _startThemeUpdate();
    }
  }

  void _startThemeUpdate() {
    if (_closed || _themeTask != null) return;
    _themeTask = _drainThemes().whenComplete(() {
      _themeTask = null;
      if (!_closed &&
          _initialized &&
          _pendingTheme != null &&
          _themeTimer?.isActive != true) {
        _startThemeUpdate();
      }
    });
  }

  Future<void> _drainThemes() async {
    await _navigation;
    if (_closed || !_initialized) return;
    navigator.beginThemeRefresh();
    _renderHealthy = false;
    try {
      while (!_closed && _pendingTheme != null) {
        final theme = _pendingTheme!;
        final force = _forceTheme;
        _pendingTheme = null;
        _forceTheme = false;
        if (!force && theme == _appliedTheme) continue;
        await _viewport.updateTheme(theme);
        if (_closed) return;
        _appliedTheme = theme;
      }
      _renderHealthy = true;
      if (failure.value == ReaderFailure.render) failure.value = null;
    } catch (error, stack) {
      _fail(ReaderFailure.render, error, stack);
    } finally {
      if (!_closed) navigator.endThemeRefresh();
    }
  }

  void _recordProgress() {
    if (_closed) return;
    final nav = navigator.state.value;
    _progress.record(
      (
        chapterIndex: nav.spineIndex,
        pageIndex: nav.pageInChapter,
        pageCount: nav.totalPagesInChapter,
      ),
      isReady:
          _renderHealthy &&
          book.isLoaded &&
          !nav.isBusy &&
          nav.spineIndex < book.spine.length,
    );
  }

  /// 退到后台或离开页面前保存；失败保留最新位置供重试。
  Future<bool> flush() {
    if (!_closed) _recordProgress();
    return _progress.flush();
  }

  /// 立即停止状态更新，返回最后一次保存结果；重复关闭共用同一结果。
  Future<bool> close() {
    if (_closing != null) return _closing!;
    _recordProgress();
    _closed = true;
    _themeTimer?.cancel();
    _pendingTheme = null;
    navigator.state.removeListener(_recordProgress);
    navigator.dispose();
    failure.dispose();
    return _closing = _progress.close();
  }

  void _fail(ReaderFailure code, [Object? error, StackTrace? stack]) {
    if (error != null) {
      appLogger.e('阅读流程失败：${code.name}', error: error, stackTrace: stack);
    }
    if (!_closed) {
      failure.value = null;
      failure.value = code;
    }
  }
}
