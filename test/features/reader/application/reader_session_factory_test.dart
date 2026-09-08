import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/repositories/book_manifest_repository_provider.dart';
import 'package:synlen/src/features/library/data/repositories/shelf_book_repository_provider.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';

import 'reader_session_factory_test.mocks.dart';

/// 装配入口：presentation 不再自己 ref.read data 层，而是由本 provider 注入。
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
    totalChapters: 1,
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

  test('createSession 用被覆盖的仓库装配会话并驱动加载', () async {
    final shelfRepo = MockShelfBookRepository();
    final manifestRepo = MockBookManifestRepository();
    when(shelfRepo.getBookByHash('hash1')).thenAnswer((_) async => buildBook());
    when(manifestRepo.getManifestByHash('hash1')).thenAnswer((_) async => null);

    final container = ProviderContainer(
      overrides: [
        shelfBookRepositoryProvider.overrideWithValue(shelfRepo),
        bookManifestRepositoryProvider.overrideWithValue(manifestRepo),
      ],
    );
    addTearDown(container.dispose);

    final session = container
        .read(readerSessionFactoryProvider.notifier)
        .createSession('hash1');

    expect(session.fileHash, 'hash1');

    await session.loadBook();

    verify(shelfRepo.getBookByHash('hash1')).called(1);
    verify(manifestRepo.getManifestByHash('hash1')).called(1);
  });
}
