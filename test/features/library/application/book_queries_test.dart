import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

import 'book_queries_test.mocks.dart';

/// 宿主（reader）用的书目查询入口：行映射成窄视图，把仓库的 Either 结果翻译成异常。
@GenerateMocks([ShelfBookRepository, BookManifestRepository])
void main() {
  provideDummy<Either<String, bool>>(const Right(true));

  late MockShelfBookRepository shelfRepo;
  late MockBookManifestRepository manifestRepo;
  late RepositoryBookQueries queries;

  setUp(() {
    shelfRepo = MockShelfBookRepository();
    manifestRepo = MockBookManifestRepository();
    queries = RepositoryBookQueries(
      shelfBookRepository: shelfRepo,
      manifestRepository: manifestRepo,
    );
  });

  test('findBook / findManifest 透传仓库结果', () async {
    when(shelfRepo.getBookByHash('hash1')).thenAnswer((_) async => null);
    when(manifestRepo.getManifestByHash('hash1')).thenAnswer((_) async => null);

    expect(await queries.findBook('hash1'), isNull);
    expect(await queries.findManifest('hash1'), isNull);
  });

  test('findBook / findManifest 把行映射成阅读视图', () async {
    when(shelfRepo.getBookByHash('hash1')).thenAnswer(
      (_) async => ShelfBook(
        id: 7,
        fileHash: 'hash1',
        filePath: 'books/hash1.epub',
        title: '测试书',
        author: '作者',
        authors: const ['作者'],
        subjects: const [],
        totalChapters: 3,
        epubVersion: '3.0',
        format: BookFormat.epub,
        importDate: 0,
        direction: 1,
        currentChapterIndex: 2,
        readingProgress: 0.5,
        chapterScrollPosition: 0.25,
        isFinished: false,
        isDeleted: false,
        updatedAt: 0,
      ),
    );
    when(manifestRepo.getManifestByHash('hash1')).thenAnswer(
      (_) async => BookManifest(
        id: 3,
        fileHash: 'hash1',
        opfRootPath: 'OEBPS/',
        spine: [SpineItem(index: 0, href: 'ch1.xhtml')],
        toc: [
          TocItem(
            label: '第一章',
            href: Href(path: 'ch1.xhtml'),
          ),
        ],
        manifest: const [],
        epubVersion: '3.0',
        format: BookFormat.epub,
        lastUpdated: DateTime(2026, 1, 1),
      ),
    );

    final book = await queries.findBook('hash1');
    expect(book, isNotNull);
    expect(book!.id, 7);
    expect(book.title, '测试书');
    expect(book.author, '作者');
    expect(book.coverPath, isNull);
    expect(book.filePath, 'books/hash1.epub');
    expect(book.totalChapters, 3);
    expect(book.direction, 1);
    expect(book.currentChapterIndex, 2);
    expect(book.chapterScrollPosition, 0.25);

    final manifest = await queries.findManifest('hash1');
    expect(manifest, isNotNull);
    expect(manifest!.spine.single.href, 'ch1.xhtml');
    expect(manifest.toc.single.label, '第一章');
  });

  test('saveProgress 成功时不抛异常', () async {
    when(
      shelfRepo.updateProgress(
        bookId: anyNamed('bookId'),
        currentChapterIndex: anyNamed('currentChapterIndex'),
        progress: anyNamed('progress'),
        scrollPosition: anyNamed('scrollPosition'),
      ),
    ).thenAnswer((_) async => const Right(true));

    await expectLater(
      queries.saveProgress(
        bookId: 1,
        chapterIndex: 2,
        progress: 0.5,
        scrollPosition: 0.25,
      ),
      completes,
    );
  });

  for (final result in <Either<String, bool>>[
    const Left('磁盘不可写'),
    const Right(false),
  ]) {
    test('仓库返回 $result 时抛 StateError', () async {
      when(
        shelfRepo.updateProgress(
          bookId: anyNamed('bookId'),
          currentChapterIndex: anyNamed('currentChapterIndex'),
          progress: anyNamed('progress'),
          scrollPosition: anyNamed('scrollPosition'),
        ),
      ).thenAnswer((_) async => result);

      await expectLater(
        queries.saveProgress(
          bookId: 1,
          chapterIndex: 0,
          progress: 0.1,
          scrollPosition: null,
        ),
        throwsStateError,
      );
    });
  }
}
