import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/data/book_session.dart';

import 'book_session_test.mocks.dart';

@GenerateMocks([ShelfBookRepository, BookManifestRepository])
void main() {
  provideDummy<Either<String, bool>>(const Right(true));

  ShelfBook buildBook({
    int id = 1,
    int currentChapterIndex = 0,
    double readingProgress = 0,
    double? chapterScrollPosition,
    int direction = 0,
  }) {
    return ShelfBook(
      id: id,
      fileHash: 'hash1',
      title: '测试书',
      author: '作者',
      authors: const ['作者'],
      subjects: const [],
      totalChapters: 3,
      epubVersion: '3.0',
      importDate: 0,
      direction: direction,
      currentChapterIndex: currentChapterIndex,
      readingProgress: readingProgress,
      chapterScrollPosition: chapterScrollPosition,
      isFinished: false,
      isDeleted: false,
      updatedAt: 0,
    );
  }

  BookManifest buildManifest({List<SpineItem>? spine, List<TocItem>? toc}) {
    return BookManifest(
      id: 1,
      fileHash: 'hash1',
      opfRootPath: 'OEBPS/',
      spine:
          spine ??
          [
            SpineItem(index: 0, href: 'ch1.xhtml'),
            SpineItem(index: 1, href: 'ch2.xhtml', linear: false),
          ],
      toc:
          toc ??
          [
            TocItem(
              label: '1.2 节',
              href: Href(path: 'ch1.xhtml', anchor: 'sec2'),
            ),
          ],
      manifest: const [],
      epubVersion: '3.0',
      lastUpdated: DateTime(2026, 1, 1),
    );
  }

  (BookSession, MockShelfBookRepository, MockBookManifestRepository)
  buildSession() {
    final shelfRepo = MockShelfBookRepository();
    final manifestRepo = MockBookManifestRepository();
    final session = BookSession(
      fileHash: 'hash1',
      shelfBookRepository: shelfRepo,
      manifestRepository: manifestRepo,
    );
    return (session, shelfRepo, manifestRepo);
  }

  group('BookSession.loadBook', () {
    test('should load book and manifest and filter non-linear spine', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook(direction: 1));
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());

      final loaded = await session.loadBook();

      expect(loaded, isTrue);
      expect(session.isLoaded, isTrue);
      expect(session.direction, 1);
      expect(session.spine.length, 1);
      expect(session.spine.single.href, 'ch1.xhtml');
      expect(session.noLinearSpine.single.href, 'ch2.xhtml');
    });

    test('should return false when the book is missing', () async {
      final (session, shelfRepo, _) = buildSession();
      when(shelfRepo.getBookByHash('hash1')).thenAnswer((_) async => null);

      expect(await session.loadBook(), isFalse);
      expect(session.isLoaded, isFalse);
    });

    test('should return false when the manifest is missing', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => null);

      expect(await session.loadBook(), isFalse);
    });
  });

  group('BookSession TOC 查找', () {
    test('should build anchor lookup maps from nested TOC', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(manifestRepo.getManifestByHash('hash1')).thenAnswer(
        (_) async => buildManifest(
          toc: [
            TocItem(
              label: '第一章',
              href: Href(path: 'ch1.xhtml', anchor: 'top'),
              children: [
                TocItem(
                  label: '1.1 节',
                  href: Href(path: 'ch1.xhtml', anchor: 'sec1'),
                ),
                TocItem(
                  label: '1.2 节',
                  href: Href(path: 'ch1.xhtml', anchor: 'sec2'),
                ),
              ],
            ),
          ],
        ),
      );
      await session.loadBook();

      expect(session.getAnchorsForSpine('ch1.xhtml'), ['top', 'sec1', 'sec2']);
      expect(session.getAnchorsForSpine('missing.xhtml'), isEmpty);
      expect(
        session.findSpineIndexForTocItem(
          TocItem(
            href: Href(path: 'ch1.xhtml', anchor: 'sec1'),
          ),
        ),
        0,
      );
    });

    test(
      'findFirstValidHref should walk down to the first child with a path',
      () {
        final (session, _, _) = buildSession();
        final item = TocItem(
          children: [
            TocItem(
              children: [
                TocItem(
                  href: Href(path: 'ch3.xhtml', anchor: 'top'),
                ),
              ],
            ),
          ],
        );

        expect(
          session.findFirstValidHref(item),
          Href(path: 'ch3.xhtml', anchor: 'top'),
        );
        expect(session.findFirstValidHref(TocItem()), isNull);
      },
    );
  });

  group('BookSession URL 与索引', () {
    test('getSpineItemUrl should build a URL for a valid index', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      final url = session.getSpineItemUrl(0, 'sec2');
      expect(url, contains('epub://localhost/book/hash1/ch1.xhtml'));
      expect(url, endsWith('#sec2'));
      expect(session.getSpineItemUrl(99), isEmpty);
    });

    test('findSpineIndexByUrl should resolve full and relative URLs', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      expect(
        session.findSpineIndexByUrl('epub://localhost/book/hash1/ch1.xhtml'),
        0,
      );
      expect(session.findSpineIndexByUrl('ch1.xhtml#sec2'), 0);
      expect(session.findSpineIndexByUrl('nope.xhtml'), isNull);
    });
  });

  group('BookSession 激活目录', () {
    test('resolveActiveItems should map active anchors to TOC items', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      session.updateActiveAnchors(['sec2']);
      final items = session.resolveActiveItems(0);
      expect(items, hasLength(1));
      expect(items.single.label, '1.2 节');
    });

    test(
      'resolveActiveItems should fall back when no anchor matches',
      () async {
        final (session, shelfRepo, manifestRepo) = buildSession();
        when(
          shelfRepo.getBookByHash('hash1'),
        ).thenAnswer((_) async => buildBook());
        when(
          manifestRepo.getManifestByHash('hash1'),
        ).thenAnswer((_) async => buildManifest());
        await session.loadBook();

        session.updateActiveAnchors(['nope']);
        expect(session.resolveActiveItems(0), hasLength(1));
      },
    );

    test(
      'generateActivatedHrefKeys should build hrefs for active anchors',
      () async {
        final (session, shelfRepo, manifestRepo) = buildSession();
        when(
          shelfRepo.getBookByHash('hash1'),
        ).thenAnswer((_) async => buildBook());
        when(
          manifestRepo.getManifestByHash('hash1'),
        ).thenAnswer((_) async => buildManifest());
        await session.loadBook();

        session.updateActiveAnchors(['sec2', 'sec3']);
        expect(session.generateActivatedHrefKeys(0), {
          Href(path: 'ch1.xhtml', anchor: 'sec2'),
          Href(path: 'ch1.xhtml', anchor: 'sec3'),
        });
      },
    );
  });

  group('BookSession.saveProgress', () {
    void stubUpdateProgress(MockShelfBookRepository repo) {
      when(
        repo.updateProgress(
          bookId: anyNamed('bookId'),
          currentChapterIndex: anyNamed('currentChapterIndex'),
          progress: anyNamed('progress'),
          scrollPosition: anyNamed('scrollPosition'),
        ),
      ).thenAnswer((_) async => const Right(true));
    }

    test('should debounce rapid saves into a single update', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.getBookByHash('hash1'),
      ).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());
      stubUpdateProgress(shelfRepo);
      await session.loadBook();

      fakeAsync((async) {
        session.saveProgress(
          currentChapterIndex: 0,
          currentPageInChapter: 1,
          totalPagesInChapter: 10,
        );
        session.saveProgress(
          currentChapterIndex: 0,
          currentPageInChapter: 5,
          totalPagesInChapter: 10,
        );

        async.elapse(const Duration(milliseconds: 20));
        async.flushMicrotasks();

        // 两次连续保存只落库一次，且保留最后一次的进度：
        // progress = 0 + 1.0 * ((5 + 1) / 10) = 0.6，scrollPosition = 0.5。
        final verification = verify(
          shelfRepo.updateProgress(
            bookId: captureAnyNamed('bookId'),
            currentChapterIndex: captureAnyNamed('currentChapterIndex'),
            progress: captureAnyNamed('progress'),
            scrollPosition: captureAnyNamed('scrollPosition'),
          ),
        );
        verification.called(1);
        expect(verification.captured, [1, 0, 0.6, 0.5]);
      });
    });
  });

  group('BookSession 初始位置', () {
    test('should expose the persisted reading position', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.getBookByHash('hash1')).thenAnswer(
        (_) async =>
            buildBook(currentChapterIndex: 2, chapterScrollPosition: 0.42),
      );
      when(
        manifestRepo.getManifestByHash('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      expect(session.initialChapterIndex, 2);
      expect(session.initialScrollPosition, 0.42);
    });
  });
}
