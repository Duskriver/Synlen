import 'package:flutter/foundation.dart';
import 'package:synlen/src/core/services/app_logger.dart';

import '../../library/domain/book_manifest.dart';
import 'book_session.dart';
import 'chapter_navigation.dart';
import 'page_navigation.dart';
import 'reader_viewport.dart';

/// 导航请求的结果；presentation 据此映射 l10n 提示，不在 application 拼文案。
enum ReaderNavOutcome {
  moved,
  ignored,
  firstChapter,
  lastChapter,
  firstPageOfBook,
  lastPageOfBook,
  tocItemHasNoContent,
  tocItemNotInSpine,
}

/// 阅读导航的只读状态：位置、页数与忙态。
@immutable
class ReaderNavState {
  const ReaderNavState({
    this.spineIndex = 0,
    this.pageInChapter = 0,
    this.totalPagesInChapter = 0,
    this.isLoading = true,
    this.isChangingChapter = false,
    this.isRefreshingTheme = false,
  });

  final int spineIndex;
  final int pageInChapter;
  final int totalPagesInChapter;
  final bool isLoading;
  final bool isChangingChapter;
  final bool isRefreshingTheme;

  /// 加载中 / 主题刷新中 / 正在翻章时忽略新的导航请求。
  bool get isBusy => shouldIgnoreChapterNavigation(
    isWebViewLoading: isLoading,
    updatingTheme: isRefreshingTheme,
    isChangingChapter: isChangingChapter,
  );

  ReaderNavState copyWith({
    int? spineIndex,
    int? pageInChapter,
    int? totalPagesInChapter,
    bool? isLoading,
    bool? isChangingChapter,
    bool? isRefreshingTheme,
  }) {
    return ReaderNavState(
      spineIndex: spineIndex ?? this.spineIndex,
      pageInChapter: pageInChapter ?? this.pageInChapter,
      totalPagesInChapter: totalPagesInChapter ?? this.totalPagesInChapter,
      isLoading: isLoading ?? this.isLoading,
      isChangingChapter: isChangingChapter ?? this.isChangingChapter,
      isRefreshingTheme: isRefreshingTheme ?? this.isRefreshingTheme,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderNavState &&
        other.spineIndex == spineIndex &&
        other.pageInChapter == pageInChapter &&
        other.totalPagesInChapter == totalPagesInChapter &&
        other.isLoading == isLoading &&
        other.isChangingChapter == isChangingChapter &&
        other.isRefreshingTheme == isRefreshingTheme;
  }

  @override
  int get hashCode => Object.hash(
    spineIndex,
    pageInChapter,
    totalPagesInChapter,
    isLoading,
    isChangingChapter,
    isRefreshingTheme,
  );
}

/// 阅读导航状态机：章节与页面位置、忙态守卫与渲染器编排。
///
/// 位置与忙态只有这一个拥有者；presentation 监听 [state] 渲染，不再各自复制字段。
class ReaderNavigator {
  ReaderNavigator({
    required BookSession session,
    required ReaderViewport viewport,
    Duration settleDelay = const Duration(milliseconds: 30),
  }) : _session = session,
       _viewport = viewport,
       _settleDelay = settleDelay;

  final BookSession _session;
  final ReaderViewport _viewport;

  /// 预载完成后的渲染沉降等待；presentation 行为不变，测试传 Duration.zero。
  final Duration _settleDelay;

  /// 只读导航状态；presentation 监听它渲染页码与忙态。
  final ValueNotifier<ReaderNavState> state = ValueNotifier(
    const ReaderNavState(),
  );

  bool _disposed = false;

  BookSession get session => _session;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    state.dispose();
  }

  void _set(ReaderNavState next) {
    if (_disposed) return;
    state.value = next;
  }

  /// 装载当前章：按 [anchor] 预载窗口，可选恢复章内滚动位置。
  Future<void> load({
    String anchor = 'top',
    int? overrideSpineIndex,
    double? restoreScrollRatio,
  }) async {
    if (_disposed || _session.spine.isEmpty) return;

    _set(state.value.copyWith(totalPagesInChapter: 0, isLoading: true));

    if (overrideSpineIndex != null &&
        overrideSpineIndex >= 0 &&
        overrideSpineIndex < _session.spine.length) {
      _set(state.value.copyWith(spineIndex: overrideSpineIndex));
    }

    final tokensForWait = <int>[];
    for (final request in planChapterPreload(
      _session,
      index: state.value.spineIndex,
      anchor: anchor,
    )) {
      final token = await _viewport.preloadChapter(request);
      if (token != null) tokensForWait.add(token);
    }

    await _viewport.waitForEvents(tokensForWait);
    if (_disposed) return;

    if (restoreScrollRatio != null) {
      await _viewport.restoreScrollPosition(restoreScrollRatio);
    }

    await Future<void>.delayed(_settleDelay);
    if (_disposed) return;

    _set(state.value.copyWith(isLoading: false));
  }

  /// 跳到 [index] 章（可带锚点）。
  Future<ReaderNavOutcome> goToChapter(
    int index, {
    String anchor = 'top',
  }) async {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;
    if (index < 0 || index >= _session.spine.length) {
      return ReaderNavOutcome.ignored;
    }

    _set(state.value.copyWith(spineIndex: index, pageInChapter: 0));
    await load(anchor: anchor);
    return ReaderNavOutcome.moved;
  }

  /// 跳到下一章首页。
  Future<ReaderNavOutcome> nextChapter() async {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;
    if (state.value.spineIndex >= _session.spine.length - 1) {
      return ReaderNavOutcome.lastChapter;
    }

    _set(state.value.copyWith(isChangingChapter: true, totalPagesInChapter: 0));
    await _viewport.jumpToNextChapter();
    if (_disposed) return ReaderNavOutcome.ignored;

    _set(
      state.value.copyWith(
        spineIndex: state.value.spineIndex + 1,
        pageInChapter: 0,
        isChangingChapter: false,
      ),
    );
    await _preloadNeighbour(forward: true);
    return ReaderNavOutcome.moved;
  }

  /// 跳到上一章末页。
  Future<ReaderNavOutcome> previousChapter() async {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;
    if (state.value.spineIndex <= 0) return ReaderNavOutcome.firstChapter;

    _set(state.value.copyWith(isChangingChapter: true, totalPagesInChapter: 0));
    await _viewport.jumpToPreviousChapterLastPage();
    if (_disposed) return ReaderNavOutcome.ignored;

    _set(
      state.value.copyWith(
        spineIndex: state.value.spineIndex - 1,
        isChangingChapter: false,
      ),
    );
    await _preloadNeighbour(forward: false);
    return ReaderNavOutcome.moved;
  }

  /// 跳到上一章首页。
  Future<ReaderNavOutcome> previousChapterFirstPage() async {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;
    if (state.value.spineIndex <= 0) return ReaderNavOutcome.firstChapter;

    _set(state.value.copyWith(isChangingChapter: true, totalPagesInChapter: 0));
    await _viewport.jumpToPreviousChapterFirstPage();
    if (_disposed) return ReaderNavOutcome.ignored;

    _set(
      state.value.copyWith(
        spineIndex: state.value.spineIndex - 1,
        pageInChapter: 0,
        isChangingChapter: false,
      ),
    );
    await _preloadNeighbour(forward: false);
    return ReaderNavOutcome.moved;
  }

  /// 跳到目录项指向的章节。
  Future<ReaderNavOutcome> goToTocItem(TocItem item) async {
    final targetHref = _session.findFirstValidHref(item);
    if (targetHref == null) return ReaderNavOutcome.tocItemHasNoContent;

    final index = _session.findSpineIndexForTocItem(item);
    if (index == null) {
      appLogger.w('目录项不在 spine 中：${targetHref.path}');
      return ReaderNavOutcome.tocItemNotInSpine;
    }

    return goToChapter(index, anchor: targetHref.anchor);
  }

  /// 能否翻页；越出全书首 / 末页时返回对应语义供 UI 提示。
  ReaderNavOutcome canTurnPage(bool isNext) {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;

    final boundary = resolvePageTurnBoundary(
      isNext: isNext,
      currentPage: state.value.pageInChapter,
      totalPages: state.value.totalPagesInChapter,
      currentSpineIndex: state.value.spineIndex,
      spineLength: _session.spine.length,
    );

    return switch (boundary) {
      PageTurnBoundary.ok => ReaderNavOutcome.moved,
      PageTurnBoundary.firstPageOfBook => ReaderNavOutcome.firstPageOfBook,
      PageTurnBoundary.lastPageOfBook => ReaderNavOutcome.lastPageOfBook,
    };
  }

  /// 翻页；章内越界时跨章。
  Future<ReaderNavOutcome> turnPage(bool isNext) async {
    final target = pageTurnTargetIndex(
      isNext: isNext,
      currentPage: state.value.pageInChapter,
      totalPages: state.value.totalPagesInChapter,
    );
    if (target == null) {
      return isNext ? nextChapter() : previousChapter();
    }
    return goToPage(target);
  }

  /// 跳到本章第 [pageIndex] 页。
  Future<ReaderNavOutcome> goToPage(int pageIndex) async {
    if (_disposed || state.value.isBusy) return ReaderNavOutcome.ignored;
    if (pageIndex < 0 || pageIndex >= state.value.totalPagesInChapter) {
      return ReaderNavOutcome.ignored;
    }

    await _viewport.jumpToPage(pageIndex);
    return ReaderNavOutcome.moved;
  }

  /// 渲染器报告章内总页数；当前页越界时收敛到末页。
  void reportPageCount(int totalPages) {
    if (_disposed) return;
    final clampedPage = state.value.pageInChapter >= totalPages
        ? (totalPages > 0 ? totalPages - 1 : 0)
        : state.value.pageInChapter;
    _set(
      state.value.copyWith(
        totalPagesInChapter: totalPages,
        pageInChapter: clampedPage,
      ),
    );
  }

  /// 渲染器报告章内当前页变化。
  void reportPageIndex(int pageIndex) {
    if (_disposed) return;
    _set(state.value.copyWith(pageInChapter: pageIndex));
  }

  /// 主题刷新开始：期间忽略导航请求。
  void beginThemeRefresh() {
    if (_disposed) return;
    _set(state.value.copyWith(isRefreshingTheme: true));
  }

  /// 主题刷新结束。
  void endThemeRefresh() {
    if (_disposed) return;
    _set(state.value.copyWith(isRefreshingTheme: false));
  }

  Future<void> _preloadNeighbour({required bool forward}) async {
    final request = planNeighbourPreload(
      _session,
      index: state.value.spineIndex,
      forward: forward,
    );
    if (request == null || _disposed) return;
    await _viewport.preloadChapter(request);
  }
}
