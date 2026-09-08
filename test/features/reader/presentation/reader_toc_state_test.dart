import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';
import 'package:synlen/src/features/reader/presentation/reader_toc_state.dart';

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

ShelfBook _buildBook() => ShelfBook(
  id: 1,
  fileHash: 'hash1',
  title: '测试书',
  author: '作者',
  authors: const ['作者'],
  subjects: const [],
  totalChapters: 2,
  epubVersion: '3.0',
  format: BookFormat.epub,
  importDate: 0,
  direction: 0,
  currentChapterIndex: 0,
  readingProgress: 0,
  updatedAt: 0,
  isFinished: false,
  isDeleted: false,
);

BookManifest _buildManifest() => BookManifest(
  id: 1,
  fileHash: 'hash1',
  opfRootPath: 'OEBPS/',
  spine: [
    SpineItem(index: 0, href: 'ch1.xhtml'),
    SpineItem(index: 1, href: 'ch2.xhtml'),
  ],
  toc: [
    TocItem(
      id: 0,
      label: '第一章',
      href: Href(path: 'ch1.xhtml', anchor: 'sec1'),
      depth: 0,
      spineIndex: 0,
    ),
  ],
  manifest: const [],
  epubVersion: '3.0',
  format: BookFormat.epub,
  lastUpdated: DateTime(2026, 1, 1),
);

void main() {
  late BookSession session;
  late ReaderTocState tocState;

  setUp(() async {
    session = BookSession(
      fileHash: 'hash1',
      queries: _FakeQueries(book: _buildBook(), manifest: _buildManifest()),
    );
    await session.loadBook();
    tocState = ReaderTocState();
  });

  tearDown(() => tocState.dispose());

  test('有激活锚点时显示对应目录项标题', () {
    session.updateActiveAnchors(['sec1']);

    tocState.refresh(session, 0);

    expect(tocState.activeItems.value.single.label, '第一章');
    expect(tocState.activeTitle.value, '第一章');
  });

  test('目录为空时标题回退到书名', () async {
    final emptyTocSession = BookSession(
      fileHash: 'hash1',
      queries: _FakeQueries(
        book: _buildBook(),
        manifest: BookManifest(
          id: 1,
          fileHash: 'hash1',
          opfRootPath: 'OEBPS/',
          spine: [SpineItem(index: 0, href: 'ch1.xhtml')],
          toc: const [],
          manifest: const [],
          epubVersion: '3.0',
          format: BookFormat.epub,
          lastUpdated: DateTime(2026, 1, 1),
        ),
      ),
    );
    await emptyTocSession.loadBook();

    tocState.refresh(emptyTocSession, 0);

    expect(tocState.activeTitle.value, '测试书');
  });

  test('updateAnchors 同时更新会话锚点与高亮', () {
    tocState.updateAnchors(session, 0, ['sec1']);

    expect(session.activeAnchors, {'sec1'});
    expect(tocState.activeTitle.value, '第一章');
  });

  test('重复刷新同一位置不重复通知', () {
    var notifications = 0;
    tocState.activeTitle.addListener(() => notifications++);

    tocState.refresh(session, 1);
    tocState.refresh(session, 1);

    expect(notifications, 1);
  });
}
