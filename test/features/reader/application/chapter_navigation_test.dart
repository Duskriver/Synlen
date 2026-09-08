import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';
import 'package:synlen/src/features/reader/application/chapter_navigation.dart';

import 'chapter_navigation_test.mocks.dart';

/// 从 spine_navigation_mixin 抽出的纯逻辑：预载窗口与导航守卫。
@GenerateMocks([ShelfBookRepository, BookManifestRepository])
void main() {
  provideDummy<Either<String, bool>>(const Right(true));
  provideDummy<Either<String, int>>(const Right(1));

  ShelfBook buildBook() => ShelfBook(
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
    currentChapterIndex: 0,
    readingProgress: 0,
    isFinished: false,
    isDeleted: false,
    updatedAt: 0,
  );

  BookManifest buildManifest(int chapters) => BookManifest(
    id: 1,
    fileHash: 'hash1',
    opfRootPath: 'OEBPS/',
    spine: [
      for (var i = 0; i < chapters; i++)
        SpineItem(index: i, href: 'ch${i + 1}.xhtml'),
    ],
    toc: const [],
    manifest: const [],
    epubVersion: '3.0',
    format: BookFormat.epub,
    lastUpdated: DateTime(2026, 1, 1),
  );

  Future<BookSession> loadedSession({int chapters = 3}) async {
    final shelfRepo = MockShelfBookRepository();
    final manifestRepo = MockBookManifestRepository();
    when(shelfRepo.getBookByHash('hash1')).thenAnswer((_) async => buildBook());
    when(
      manifestRepo.getManifestByHash('hash1'),
    ).thenAnswer((_) async => buildManifest(chapters));
    final session = BookSession(
      fileHash: 'hash1',
      shelfBookRepository: shelfRepo,
      manifestRepository: manifestRepo,
    );
    await session.loadBook();
    return session;
  }

  group('planChapterPreload', () {
    test('首章只有当前与下一章', () async {
      final plan = planChapterPreload(await loadedSession(), index: 0);

      expect(plan.map((r) => r.slot), [ChapterSlot.current, ChapterSlot.next]);
      expect(plan.map((r) => r.index), [0, 1]);
    });

    test('中间章给出上一、当前、下一三章，当前章使用传入 anchor', () async {
      final plan = planChapterPreload(
        await loadedSession(),
        index: 1,
        anchor: 'sec2',
      );

      expect(plan.map((r) => r.slot), [
        ChapterSlot.current,
        ChapterSlot.previous,
        ChapterSlot.next,
      ]);
      expect(plan.map((r) => r.index), [1, 0, 2]);
      expect(plan.first.url, contains('#sec2'));
      expect(plan[1].url, contains('#top'));
    });

    test('末章只有当前与上一章', () async {
      final plan = planChapterPreload(await loadedSession(), index: 2);

      expect(plan.map((r) => r.slot), [
        ChapterSlot.current,
        ChapterSlot.previous,
      ]);
    });

    test('越界索引返回空计划', () async {
      final session = await loadedSession();

      expect(planChapterPreload(session, index: -1), isEmpty);
      expect(planChapterPreload(session, index: 3), isEmpty);
    });
  });

  group('planNeighbourPreload', () {
    test('向前越界返回 null', () async {
      expect(
        planNeighbourPreload(await loadedSession(), index: 2, forward: true),
        isNull,
      );
    });

    test('向后越界返回 null', () async {
      expect(
        planNeighbourPreload(await loadedSession(), index: 0, forward: false),
        isNull,
      );
    });

    test('正常邻居返回目标章与角色', () async {
      final request = planNeighbourPreload(
        await loadedSession(),
        index: 1,
        forward: false,
      );

      expect(request?.index, 0);
      expect(request?.slot, ChapterSlot.previous);
    });
  });

  group('shouldIgnoreChapterNavigation', () {
    test('三种忙态任一为真都忽略', () {
      expect(
        shouldIgnoreChapterNavigation(
          isWebViewLoading: true,
          updatingTheme: false,
          isChangingChapter: false,
        ),
        isTrue,
      );
      expect(
        shouldIgnoreChapterNavigation(
          isWebViewLoading: false,
          updatingTheme: true,
          isChangingChapter: false,
        ),
        isTrue,
      );
      expect(
        shouldIgnoreChapterNavigation(
          isWebViewLoading: false,
          updatingTheme: false,
          isChangingChapter: true,
        ),
        isTrue,
      );
      expect(
        shouldIgnoreChapterNavigation(
          isWebViewLoading: false,
          updatingTheme: false,
          isChangingChapter: false,
        ),
        isFalse,
      );
    });
  });
}
