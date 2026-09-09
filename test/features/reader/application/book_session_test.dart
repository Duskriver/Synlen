import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';

import 'book_session_test.mocks.dart';

@GenerateMocks([BookQueries])
void main() {
  provideDummy<Either<String, bool>>(const Right(true));

  ReaderBookView buildBook({
    int id = 1,
    int currentChapterIndex = 0,
    double? chapterScrollPosition,
    int direction = 0,
  }) {
    return (
      id: id,
      title: '测试书',
      author: '作者',
      coverPath: null,
      filePath: null,
      totalChapters: 3,
      direction: direction,
      currentChapterIndex: currentChapterIndex,
      chapterScrollPosition: chapterScrollPosition,
    );
  }

  ReaderManifestView buildManifest({
    List<SpineItem>? spine,
    List<TocItem>? toc,
  }) {
    return (
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
    );
  }

  (BookSession, MockBookQueries, MockBookQueries) buildSession() {
    final queries = MockBookQueries();
    final session = BookSession(fileHash: 'hash1', queries: queries);
    return (session, queries, queries);
  }

  group('BookSession.loadBook', () {
    test('should load book and manifest and filter non-linear spine', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(
        shelfRepo.findBook('hash1'),
      ).thenAnswer((_) async => buildBook(direction: 1));
      when(
        manifestRepo.findManifest('hash1'),
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
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => null);

      expect(await session.loadBook(), isFalse);
      expect(session.isLoaded, isFalse);
    });

    test('should return false when the manifest is missing', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(manifestRepo.findManifest('hash1')).thenAnswer((_) async => null);

      expect(await session.loadBook(), isFalse);
    });
  });

  group('BookSession TOC 查找', () {
    test('should build anchor lookup maps from nested TOC', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(manifestRepo.findManifest('hash1')).thenAnswer(
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
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.findManifest('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      final url = session.getSpineItemUrl(0, 'sec2');
      expect(url, contains('book://localhost/book/hash1/ch1.xhtml'));
      expect(url, endsWith('#sec2'));
      expect(session.getSpineItemUrl(99), isEmpty);
    });

    test('findSpineIndexByUrl should resolve full and relative URLs', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.findManifest('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      expect(
        session.findSpineIndexByUrl('book://localhost/book/hash1/ch1.xhtml'),
        0,
      );
      expect(session.findSpineIndexByUrl('ch1.xhtml#sec2'), 0);
      expect(session.findSpineIndexByUrl('nope.xhtml'), isNull);
    });
  });

  group('BookSession 激活目录', () {
    test('resolveActiveItems should map active anchors to TOC items', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.findManifest('hash1'),
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
        when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
        when(
          manifestRepo.findManifest('hash1'),
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
        when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
        when(
          manifestRepo.findManifest('hash1'),
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
    void stubSaveProgress(MockBookQueries queries) {
      when(
        queries.saveProgress(
          bookId: anyNamed('bookId'),
          chapterIndex: anyNamed('chapterIndex'),
          progress: anyNamed('progress'),
          scrollPosition: anyNamed('scrollPosition'),
        ),
      ).thenAnswer((_) async {});
    }

    test('等待真实写入完成并按线性章节计算进度', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(manifestRepo.findManifest('hash1')).thenAnswer(
        (_) async => buildManifest(
          spine: [
            SpineItem(index: 0, href: 'a.xhtml'),
            SpineItem(index: 1, href: 'skip.xhtml', linear: false),
            SpineItem(index: 2, href: 'b.xhtml'),
          ],
        ),
      );
      final write = Completer<void>();
      when(
        shelfRepo.saveProgress(
          bookId: 1,
          chapterIndex: 1,
          progress: 0.8,
          scrollPosition: 0.5,
        ),
      ).thenAnswer((_) => write.future);
      await session.loadBook();
      var completed = false;
      final saving = session
          .saveProgress((chapterIndex: 1, pageIndex: 5, pageCount: 10))
          .then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      write.complete();
      await saving;
      expect(completed, isTrue);
      verify(
        shelfRepo.saveProgress(
          bookId: 1,
          chapterIndex: 1,
          progress: 0.8,
          scrollPosition: 0.5,
        ),
      ).called(1);
    });

    test('仓库写入失败时必须报告失败', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.findManifest('hash1'),
      ).thenAnswer((_) async => buildManifest());
      when(
        shelfRepo.saveProgress(
          bookId: anyNamed('bookId'),
          chapterIndex: anyNamed('chapterIndex'),
          progress: anyNamed('progress'),
          scrollPosition: anyNamed('scrollPosition'),
        ),
      ).thenThrow(StateError('磁盘不可写'));
      await session.loadBook();
      await expectLater(
        session.saveProgress((chapterIndex: 0, pageIndex: 0, pageCount: 10)),
        throwsStateError,
      );
    });

    test('无效位置与未加载会话不得写入数据库', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      stubSaveProgress(shelfRepo);
      await expectLater(
        session.saveProgress((chapterIndex: 0, pageIndex: 0, pageCount: 10)),
        throwsStateError,
      );
      when(shelfRepo.findBook('hash1')).thenAnswer((_) async => buildBook());
      when(
        manifestRepo.findManifest('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();
      for (final position in [
        (chapterIndex: -1, pageIndex: 0, pageCount: 10),
        (chapterIndex: 1, pageIndex: 0, pageCount: 10),
        (chapterIndex: 0, pageIndex: -1, pageCount: 10),
        (chapterIndex: 0, pageIndex: 10, pageCount: 10),
        (chapterIndex: 0, pageIndex: 0, pageCount: 0),
      ]) {
        await expectLater(session.saveProgress(position), throwsArgumentError);
      }
      verifyNever(
        shelfRepo.saveProgress(
          bookId: anyNamed('bookId'),
          chapterIndex: anyNamed('chapterIndex'),
          progress: anyNamed('progress'),
          scrollPosition: anyNamed('scrollPosition'),
        ),
      );
    });
  });

  group('BookSession 初始位置', () {
    test('should expose the persisted reading position', () async {
      final (session, shelfRepo, manifestRepo) = buildSession();
      when(shelfRepo.findBook('hash1')).thenAnswer(
        (_) async =>
            buildBook(currentChapterIndex: 2, chapterScrollPosition: 0.42),
      );
      when(
        manifestRepo.findManifest('hash1'),
      ).thenAnswer((_) async => buildManifest());
      await session.loadBook();

      expect(session.initialChapterIndex, 2);
      expect(session.initialScrollPosition, 0.42);
    });
  });
}
