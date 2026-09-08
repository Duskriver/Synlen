import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';
import 'package:synlen/src/features/reader/application/chapter_navigation.dart';
import 'package:synlen/src/features/reader/application/reader_navigator.dart';
import 'package:synlen/src/features/reader/application/reader_viewport.dart';

/// 记录调用序列的视口 fake：断言导航编排而不碰 WebView。
class _FakeViewport implements ReaderViewport {
  final List<String> calls = [];
  double? restoredRatio;

  @override
  Future<int?> preloadChapter(ChapterPreloadRequest request) async {
    calls.add('preload:${request.slot.name}:${request.index}');
    return request.index;
  }

  @override
  Future<void> waitForEvents(List<int> tokens) async {
    calls.add('wait:${tokens.length}');
  }

  @override
  Future<void> restoreScrollPosition(double ratio) async {
    restoredRatio = ratio;
    calls.add('restore');
  }

  @override
  Future<void> jumpToPreviousChapterLastPage() async => calls.add('prevLast');

  @override
  Future<void> jumpToPreviousChapterFirstPage() async => calls.add('prevFirst');

  @override
  Future<void> jumpToNextChapter() async => calls.add('nextChapter');

  @override
  Future<void> jumpToPage(int pageIndex) async => calls.add('page:$pageIndex');
}

class _FakeQueries implements BookQueries {
  _FakeQueries({required this.book, required this.manifest});

  final ShelfBook book;
  final BookManifest manifest;

  @override
  Future<ShelfBook?> findBook(String fileHash) async => book;

  @override
  Future<BookManifest?> findManifest(String fileHash) async => manifest;

  @override
  Future<void> saveProgress({
    required int bookId,
    required int chapterIndex,
    required double progress,
    required double? scrollPosition,
  }) async {}
}

ShelfBook _buildBook({int currentChapterIndex = 0}) => ShelfBook(
  id: 1,
  fileHash: 'hash1',
  title: '测试书',
  author: '作者',
  authors: const ['作者'],
  subjects: const [],
  totalChapters: 3,
  epubVersion: '3.0',
  format: BookFormat.epub,
  importDate: 0,
  direction: 0,
  currentChapterIndex: currentChapterIndex,
  readingProgress: 0,
  isFinished: false,
  isDeleted: false,
  updatedAt: 0,
);

BookManifest _buildManifest({int chapters = 3, List<TocItem>? toc}) =>
    BookManifest(
      id: 1,
      fileHash: 'hash1',
      opfRootPath: 'OEBPS/',
      spine: [
        for (var i = 0; i < chapters; i++)
          SpineItem(index: i, href: 'ch${i + 1}.xhtml'),
      ],
      toc:
          toc ??
          [
            TocItem(
              id: 0,
              label: '第二章',
              href: Href(path: 'ch2.xhtml', anchor: 'top'),
              depth: 0,
              spineIndex: 1,
            ),
          ],
      manifest: const [],
      epubVersion: '3.0',
      format: BookFormat.epub,
      lastUpdated: DateTime(2026, 1, 1),
    );

void main() {
  late _FakeViewport viewport;
  late BookSession session;
  late ReaderNavigator navigator;

  Future<void> setUpNavigator({
    int chapters = 3,
    int currentChapterIndex = 0,
    List<TocItem>? toc,
  }) async {
    viewport = _FakeViewport();
    session = BookSession(
      fileHash: 'hash1',
      queries: _FakeQueries(
        book: _buildBook(currentChapterIndex: currentChapterIndex),
        manifest: _buildManifest(chapters: chapters, toc: toc),
      ),
    );
    await session.loadBook();
    navigator = ReaderNavigator(
      session: session,
      viewport: viewport,
      settleDelay: Duration.zero,
    );
  }

  tearDown(() => navigator.dispose());

  group('ReaderNavigator.load', () {
    test('预载当前章与前后邻居，等待全部事件后结束加载态', () async {
      await setUpNavigator();
      await navigator.load();

      expect(viewport.calls, ['preload:current:0', 'preload:next:1', 'wait:2']);
      expect(navigator.state.value.isLoading, isFalse);
      expect(navigator.state.value.spineIndex, 0);
    });

    test('中间章预载三章，首章省略上一章', () async {
      await setUpNavigator(currentChapterIndex: 1);
      await navigator.load(overrideSpineIndex: session.initialChapterIndex);

      expect(viewport.calls, [
        'preload:current:1',
        'preload:previous:0',
        'preload:next:2',
        'wait:3',
      ]);
    });

    test('恢复滚动位置', () async {
      await setUpNavigator();
      await navigator.load(restoreScrollRatio: 0.42);

      expect(viewport.restoredRatio, 0.42);
      expect(viewport.calls, contains('restore'));
    });

    test('overrideSpineIndex 越界时保持原索引', () async {
      await setUpNavigator();
      await navigator.load(overrideSpineIndex: 99);

      expect(navigator.state.value.spineIndex, 0);
      expect(viewport.calls, contains('preload:current:0'));
    });

    test('spine 为空时不触发任何视口调用', () async {
      await setUpNavigator(chapters: 0);
      await navigator.load();

      expect(viewport.calls, isEmpty);
    });
  });

  group('ReaderNavigator 章节导航', () {
    test('加载中忽略导航请求', () async {
      await setUpNavigator();
      expect(navigator.state.value.isLoading, isTrue);

      expect(await navigator.nextChapter(), ReaderNavOutcome.ignored);
      expect(viewport.calls, isEmpty);
    });

    test('下一章：位置前移、页归零并预载新邻居', () async {
      await setUpNavigator();
      await navigator.load();

      expect(await navigator.nextChapter(), ReaderNavOutcome.moved);
      expect(navigator.state.value.spineIndex, 1);
      expect(navigator.state.value.pageInChapter, 0);
      expect(navigator.state.value.isChangingChapter, isFalse);
      expect(viewport.calls, contains('nextChapter'));
      expect(viewport.calls, contains('preload:next:2'));
    });

    test('末章再往后返回 lastChapter', () async {
      await setUpNavigator(currentChapterIndex: 2);
      await navigator.load(overrideSpineIndex: session.initialChapterIndex);

      expect(await navigator.nextChapter(), ReaderNavOutcome.lastChapter);
      expect(viewport.calls, isNot(contains('nextChapter')));
    });

    test('上一章末页：索引回退且页号保留', () async {
      await setUpNavigator(currentChapterIndex: 1);
      await navigator.load(overrideSpineIndex: session.initialChapterIndex);
      navigator.reportPageIndex(2);

      expect(await navigator.previousChapter(), ReaderNavOutcome.moved);
      expect(navigator.state.value.spineIndex, 0);
      expect(navigator.state.value.pageInChapter, 2);
      expect(viewport.calls, contains('prevLast'));
    });

    test('上一章首页：页号归零', () async {
      await setUpNavigator(currentChapterIndex: 1);
      await navigator.load(overrideSpineIndex: session.initialChapterIndex);

      expect(
        await navigator.previousChapterFirstPage(),
        ReaderNavOutcome.moved,
      );
      expect(navigator.state.value.spineIndex, 0);
      expect(navigator.state.value.pageInChapter, 0);
      expect(viewport.calls, contains('prevFirst'));
    });

    test('首章再往前返回 firstChapter', () async {
      await setUpNavigator();
      await navigator.load();

      expect(await navigator.previousChapter(), ReaderNavOutcome.firstChapter);
      expect(viewport.calls, isNot(contains('prevLast')));
    });

    test('goToChapter 越界返回 ignored', () async {
      await setUpNavigator();
      await navigator.load();

      expect(await navigator.goToChapter(9), ReaderNavOutcome.ignored);
    });
  });

  group('ReaderNavigator 翻页', () {
    test('章内翻页只跳页，不跨章', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(3);
      navigator.reportPageIndex(1);

      expect(await navigator.turnPage(true), ReaderNavOutcome.moved);
      expect(viewport.calls, contains('page:2'));
      expect(navigator.state.value.spineIndex, 0);
    });

    test('末页往后跨到下一章', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(3);
      navigator.reportPageIndex(2);

      expect(await navigator.turnPage(true), ReaderNavOutcome.moved);
      expect(viewport.calls, contains('nextChapter'));
      expect(navigator.state.value.spineIndex, 1);
    });

    test('全书首页往前返回 firstPageOfBook', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(3);

      expect(navigator.canTurnPage(false), ReaderNavOutcome.firstPageOfBook);
      expect(navigator.canTurnPage(true), ReaderNavOutcome.moved);
    });

    test('全书末页往后返回 lastPageOfBook', () async {
      await setUpNavigator(currentChapterIndex: 2);
      await navigator.load(overrideSpineIndex: session.initialChapterIndex);
      navigator.reportPageCount(3);
      navigator.reportPageIndex(2);

      expect(navigator.canTurnPage(true), ReaderNavOutcome.lastPageOfBook);
    });

    test('goToPage 越界返回 ignored', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(3);

      expect(await navigator.goToPage(3), ReaderNavOutcome.ignored);
      expect(viewport.calls, isNot(contains('page:3')));
    });
  });

  group('ReaderNavigator.reportPageCount', () {
    test('当前页超出新页数时收敛到末页', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(5);
      navigator.reportPageIndex(4);

      navigator.reportPageCount(3);

      expect(navigator.state.value.totalPagesInChapter, 3);
      expect(navigator.state.value.pageInChapter, 2);
    });

    test('页数为 0 时当前页归零', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.reportPageCount(0);

      expect(navigator.state.value.pageInChapter, 0);
    });
  });

  group('ReaderNavigator.goToTocItem', () {
    test('跳到目录项所在章节', () async {
      await setUpNavigator();
      await navigator.load();
      final item = session.toc.first;

      expect(await navigator.goToTocItem(item), ReaderNavOutcome.moved);
      expect(navigator.state.value.spineIndex, 1);
    });

    test('无有效 href 返回 tocItemHasNoContent', () async {
      await setUpNavigator(
        toc: [
          TocItem(
            id: 0,
            label: '空项',
            href: Href(path: '', anchor: 'top'),
            depth: 0,
            spineIndex: 0,
          ),
        ],
      );
      await navigator.load();

      expect(
        await navigator.goToTocItem(session.toc.first),
        ReaderNavOutcome.tocItemHasNoContent,
      );
    });

    test('href 不在 spine 中返回 tocItemNotInSpine', () async {
      await setUpNavigator(
        toc: [
          TocItem(
            id: 0,
            label: '缺失章',
            href: Href(path: 'missing.xhtml', anchor: 'top'),
            depth: 0,
            spineIndex: 0,
          ),
        ],
      );
      await navigator.load();

      expect(
        await navigator.goToTocItem(session.toc.first),
        ReaderNavOutcome.tocItemNotInSpine,
      );
    });
  });

  group('ReaderNavigator 生命周期', () {
    test('dispose 后不再接受导航', () async {
      await setUpNavigator();
      await navigator.load();
      navigator.dispose();

      expect(await navigator.nextChapter(), ReaderNavOutcome.ignored);
      expect(navigator.canTurnPage(true), ReaderNavOutcome.ignored);
    });
  });
}
