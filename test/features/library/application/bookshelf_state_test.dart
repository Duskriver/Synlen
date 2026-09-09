import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/application/bookshelf_state.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';

ShelfBookView buildBook(int id) => (
  id: id,
  fileHash: 'hash$id',
  title: '书$id',
  author: '作者',
  coverPath: null,
  readingProgress: 0,
  isFinished: false,
  isDeleted: false,
);

void main() {
  test('默认值：全部标签、放松视图、无选择', () {
    final state = BookshelfState.bookshelfState(books: const []);

    expect(state.viewMode, ViewMode.relaxed);
    expect(state.filterGroupId, isNull);
    expect(state.currentGroupId, isNull);
    expect(state.isSelectionMode, isFalse);
    expect(state.hasSelection, isFalse);
  });

  test('copyWith 覆盖单字段并保留其余', () {
    final state = BookshelfState.bookshelfState(books: [buildBook(1)]);

    final next = state.copyWith(viewMode: ViewMode.compact);

    expect(next.viewMode, ViewMode.compact);
    expect(next.books, same(state.books));
    expect(next.filterGroupId, isNull);
  });

  test('clearFilter 显式清空分组过滤', () {
    final state = BookshelfState.bookshelfState(
      books: const [],
      filterGroupId: 3,
    );

    expect(state.copyWith(clearFilter: true).filterGroupId, isNull);
    expect(state.copyWith().filterGroupId, 3);
  });

  test('clearGroup 显式清空当前分组', () {
    final state = BookshelfState.bookshelfState(
      books: const [],
      currentGroupId: 5,
    );

    expect(state.copyWith(clearGroup: true).currentGroupId, isNull);
    expect(state.copyWith().currentGroupId, 5);
  });

  test('selectedCount 汇总书与分组的选择数', () {
    final state = BookshelfState.bookshelfState(
      books: const [],
      selectedBookIds: {1, 2},
      selectedGroupIds: {9},
    );

    expect(state.selectedCount, 3);
    expect(state.hasSelection, isTrue);
  });
}
