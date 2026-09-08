import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_actions.dart';
import 'package:synlen/src/features/library/data/repositories/shelf_book_repository_provider.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

import 'book_actions_test.mocks.dart';

/// 单本书用例的编排：读取透传、保存结果映射成「错误信息或成功」。
@GenerateMocks([ShelfBookRepository])
void main() {
  late MockShelfBookRepository repository;
  late ProviderContainer container;

  ShelfBook buildBook() {
    return ShelfBook(
      id: 1,
      fileHash: 'hash-1',
      title: '测试书',
      author: '作者',
      authors: const ['作者'],
      subjects: const [],
      totalChapters: 1,
      epubVersion: '',
      format: BookFormat.txt,
      importDate: 0,
      direction: 0,
      currentChapterIndex: 0,
      readingProgress: 0,
      isFinished: false,
      isDeleted: false,
      updatedAt: 0,
    );
  }

  setUp(() {
    repository = MockShelfBookRepository();
    provideDummy<Either<String, ShelfBook>>(right(buildBook()));
    provideDummy<Either<String, int>>(right(1));
    container = ProviderContainer(
      overrides: [shelfBookRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('findByHash 透传仓库结果', () async {
    when(
      repository.getBookByHash('hash-1'),
    ).thenAnswer((_) async => buildBook());

    final book = await container
        .read(bookActionsProvider.notifier)
        .findByHash('hash-1');

    expect(book?.fileHash, 'hash-1');
  });

  test('保存成功返回 null', () async {
    when(repository.saveBook(any)).thenAnswer((_) async => right(1));

    final error = await container
        .read(bookActionsProvider.notifier)
        .saveMetadata(buildBook());

    expect(error, isNull);
  });

  test('保存失败返回仓库给出的错误信息', () async {
    when(repository.saveBook(any)).thenAnswer((_) async => left('磁盘已满'));

    final error = await container
        .read(bookActionsProvider.notifier)
        .saveMetadata(buildBook());

    expect(error, '磁盘已满');
  });
}
