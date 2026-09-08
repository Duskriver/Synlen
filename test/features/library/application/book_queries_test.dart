import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';

import 'book_queries_test.mocks.dart';

/// 宿主（reader）用的书目查询入口：透传读取，把仓库的 Either 结果翻译成异常。
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
