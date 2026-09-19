import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';
import 'package:synlen/src/features/reader/application/chapter_navigation.dart';
import 'package:synlen/src/features/reader/application/reader_navigator.dart';
import 'package:synlen/src/features/reader/application/reader_viewport.dart';
import 'package:synlen/src/features/reader/application/reader_workflow.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

class _Queries implements BookQueries {
  final saved = <(int, double?)>[];
  bool failSave = false;
  @override
  Future<ReaderBookView?> findBook(String hash) async => (
    id: 1,
    title: '书',
    author: '',
    coverPath: null,
    filePath: '/book.txt',
    totalChapters: 3,
    direction: 0,
    currentChapterIndex: 1,
    chapterScrollPosition: 0.4,
  );
  @override
  Future<ReaderManifestView?> findManifest(String hash) async => (
    spine: List.generate(3, (i) => SpineItem(index: i, href: 'ch$i.xhtml')),
    toc: List.generate(
      3,
      (i) => TocItem(
        label: '章$i',
        href: Href(path: 'ch$i.xhtml', anchor: 'top'),
      ),
    ),
  );
  @override
  Future<void> saveProgress({
    required int bookId,
    required int chapterIndex,
    required double progress,
    required double? scrollPosition,
  }) async {
    if (failSave) throw StateError('写入失败');
    saved.add((chapterIndex, scrollPosition));
  }
}

class _Viewport implements ReaderViewport {
  late ReaderWorkflow workflow;
  Completer<void>? prepareGate;
  Completer<void>? themeGate;
  bool failTheme = false;
  bool failPrepare = false;
  int preparations = 0;
  final themes = <double>[];
  double? restored;
  @override
  Future<void> prepareChapters(List<ChapterPreloadRequest> requests) async {
    preparations++;
    await prepareGate?.future;
    if (failPrepare) throw StateError('加载失败');
    workflow.reportPageCount(10);
  }

  @override
  Future<void> updateTheme(EpubTheme theme) async {
    themes.add(theme.zoom);
    await themeGate?.future;
    if (failTheme) throw StateError('排版失败');
    workflow.reportPageCount(20);
    workflow.reportPageIndex(4);
  }

  @override
  Future<void> restoreScrollPosition(double ratio) async {
    restored = ratio;
    workflow.reportPageIndex((ratio * 10).floor());
  }

  @override
  Future<void> jumpToPage(int index) async => workflow.reportPageIndex(index);
  @override
  Future<void> jumpToNextChapter() async {
    workflow.reportPageCount(10);
    workflow.reportPageIndex(0);
  }

  @override
  Future<void> jumpToPreviousChapterFirstPage() async {
    workflow.reportPageCount(10);
    workflow.reportPageIndex(0);
  }

  @override
  Future<void> jumpToPreviousChapterLastPage() async {
    workflow.reportPageCount(10);
    workflow.reportPageIndex(9);
  }
}

EpubTheme _theme(double zoom) => EpubTheme(
  zoom: zoom,
  shouldOverrideTextColor: true,
  colorScheme: const ColorScheme.light(),
  padding: EdgeInsets.zero,
);
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  late _Queries queries;
  late _Viewport viewport;
  late ReaderWorkflow workflow;
  setUp(() {
    queries = _Queries();
    viewport = _Viewport();
    workflow = ReaderWorkflow(
      book: BookSession(fileHash: 'hash', queries: queries),
      viewport: viewport,
      settleDelay: Duration.zero,
      progressDebounce: const Duration(days: 1),
    );
    viewport.workflow = workflow;
  });
  tearDown(() => workflow.close());
  Future<void> open() async {
    expect(await workflow.open(), isTrue);
    await workflow.initializeRenderer();
  }

  test('书目加载不调用视口；视口就绪只恢复一次进度', () async {
    await workflow.open();
    expect(viewport.preparations, 0);
    await workflow.initializeRenderer();
    await workflow.initializeRenderer();
    await workflow.flush();
    expect(viewport.preparations, 1);
    expect(viewport.restored, 0.4);
    expect(queries.saved, [(1, 0.4)]);
  });

  test('初始化紧跟主题设置也能完成，重复就绪回调只恢复一次', () async {
    await workflow.open();
    workflow.requestTheme(_theme(2));
    await Future.wait([
      workflow.initializeRenderer(theme: _theme(2)),
      workflow.initializeRenderer(theme: _theme(2)),
    ]);
    await _tick();
    expect(viewport.preparations, 1);
    expect(workflow.navigator.state.value.isBusy, isFalse);
    expect(viewport.restored, 0.4);
  });

  test('目录、内部链接、翻页均自动采集进度', () async {
    await open();
    await workflow.goToTocItem(workflow.book.toc[0]);
    await workflow.flush();
    expect(queries.saved.last, (0, 0.0));
    await workflow.followInternalLink(
      'book://localhost/book/hash/ch2.xhtml#top',
    );
    await workflow.flush();
    expect(queries.saved.last, (2, 0.0));
    await workflow.turnPage(true);
    await workflow.flush();
    expect(queries.saved.last, (2, 0.1));
  });

  test('导航在途忽略第二个请求，关闭后迟到结果不再更新或保存', () async {
    await open();
    await workflow.flush();
    viewport.prepareGate = Completer<void>();
    final pending = workflow.goToChapter(2);
    expect(await workflow.goToChapter(0), ReaderNavOutcome.ignored);
    await workflow.close();
    viewport.prepareGate!.complete();
    expect(await pending, ReaderNavOutcome.ignored);
    expect(queries.saved, [(1, 0.4)]);
    expect(await workflow.nextChapter(), ReaderNavOutcome.ignored);
  });

  test('主题请求串行合并，排版完成后才保存新位置', () async {
    await open();
    await workflow.flush();
    viewport.themeGate = Completer<void>();
    workflow.requestTheme(_theme(1));
    await _tick();
    workflow.requestTheme(_theme(2));
    workflow.requestTheme(_theme(3));
    expect(await workflow.goToChapter(2), ReaderNavOutcome.ignored);
    await workflow.flush();
    expect(queries.saved, [(1, 0.4)]);
    viewport.themeGate!.complete();
    await _tick();
    await workflow.flush();
    expect(viewport.themes, [1, 3]);
    expect(queries.saved.last, (1, 0.2));
    expect(workflow.navigator.state.value.isBusy, isFalse);
  });

  test('视口尺寸变化即使主题相同也重新排版，包括在途刷新期间', () async {
    await open();
    viewport.themeGate = Completer<void>();
    workflow.requestTheme(_theme(2));
    await _tick();
    workflow.requestTheme(_theme(2), force: true);
    viewport.themeGate!.complete();
    await _tick();
    expect(viewport.themes, [2, 2]);
    workflow.requestTheme(_theme(2));
    await _tick();
    expect(viewport.themes, [2, 2]);
  });

  test('排版失败解除忙态且保留上一份进度，下一次请求可恢复', () async {
    await open();
    viewport.failTheme = true;
    workflow.requestTheme(_theme(2));
    await _tick();
    expect(workflow.failure.value, ReaderFailure.render);
    expect(workflow.navigator.state.value.isBusy, isFalse);
    viewport.failTheme = false;
    workflow.requestTheme(_theme(3));
    await _tick();
    await workflow.flush();
    expect(queries.saved.last, (1, 0.2));
  });

  test('刷新中关闭不触发迟到通知，关闭幂等', () async {
    await open();
    viewport.themeGate = Completer<void>();
    workflow.requestTheme(_theme(2));
    await _tick();
    final closing = workflow.close();
    expect(identical(closing, workflow.close()), isTrue);
    viewport.themeGate!.complete();
    await _tick();
    expect(await closing, isTrue);
    expect(queries.saved, [(1, 0.4)]);
  });

  test('导航失败解除加载态；保存失败可重试', () async {
    await open();
    viewport.failPrepare = true;
    expect(await workflow.goToChapter(2), ReaderNavOutcome.ignored);
    expect(workflow.failure.value, ReaderFailure.render);
    expect(workflow.navigator.state.value.isBusy, isFalse);
    queries.failSave = true;
    expect(await workflow.flush(), isFalse);
    expect(workflow.failure.value, ReaderFailure.progress);
    queries.failSave = false;
    expect(await workflow.flush(), isTrue);
    expect(queries.saved.last, (1, 0.4));
  });
}
