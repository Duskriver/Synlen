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

/// 单本书用例的编排：按哈希取整行、保存结果映射成「错误信息或成功」。
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

  test('saveMetadataByHash 成功返回 null 并写回编辑后的字段', () async {
    when(
      repository.getBookByHash('hash-1'),
    ).thenAnswer((_) async => buildBook());
    when(repository.saveBook(any)).thenAnswer((_) async => right(1));

    final error = await container
        .read(bookActionsProvider.notifier)
        .saveMetadataByHash(
          fileHash: 'hash-1',
          title: '新书名',
          authors: ['甲', '乙'],
          description: '新简介',
        );

    final saved =
        verify(repository.saveBook(captureAny)).captured.single as ShelfBook;
    expect(error, isNull);
    expect(saved.title, '新书名');
    expect(saved.authors, ['甲', '乙']);
    expect(saved.author, '甲');
    expect(saved.description, '新简介');
    expect(saved.fileHash, 'hash-1');
  });

  test('saveMetadataByHash 清空简介时写回 null', () async {
    when(
      repository.getBookByHash('hash-1'),
    ).thenAnswer((_) async => buildBook());
    when(repository.saveBook(any)).thenAnswer((_) async => right(1));

    await container
        .read(bookActionsProvider.notifier)
        .saveMetadataByHash(
          fileHash: 'hash-1',
          title: '书名',
          authors: const [],
          description: null,
        );

    final saved =
        verify(repository.saveBook(captureAny)).captured.single as ShelfBook;
    expect(saved.description, isNull);
    expect(saved.author, isEmpty);
  });

  test('saveMetadataByHash 找不到书时返回错误且不落库', () async {
    when(repository.getBookByHash('missing')).thenAnswer((_) async => null);

    final error = await container
        .read(bookActionsProvider.notifier)
        .saveMetadataByHash(
          fileHash: 'missing',
          title: '书名',
          authors: const [],
          description: null,
        );

    expect(error, isNotNull);
    verifyNever(repository.saveBook(any));
  });

  test('saveMetadataByHash 失败返回仓库给出的错误信息', () async {
    when(
      repository.getBookByHash('hash-1'),
    ).thenAnswer((_) async => buildBook());
    when(repository.saveBook(any)).thenAnswer((_) async => left('磁盘已满'));

    final error = await container
        .read(bookActionsProvider.notifier)
        .saveMetadataByHash(
          fileHash: 'hash-1',
          title: '书名',
          authors: const [],
          description: null,
        );

    expect(error, '磁盘已满');
  });
}
