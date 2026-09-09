import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/application/bookshelf_selection.dart';
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

BookshelfState buildState({
  List<int> bookIds = const [1, 2],
  bool isSelectionMode = false,
  Set<int> selected = const {},
}) {
  return BookshelfState.bookshelfState(
    books: bookIds.map(buildBook).toList(),
    isSelectionMode: isSelectionMode,
    selectedBookIds: selected,
  );
}

void main() {
  group('withSelectionModeToggled', () {
    test('未在多选时进入多选', () {
      final next = withSelectionModeToggled(buildState());

      expect(next.isSelectionMode, isTrue);
    });

    test('已在多选时退出并清空已选', () {
      final next = withSelectionModeToggled(
        buildState(isSelectionMode: true, selected: {1, 2}),
      );

      expect(next.isSelectionMode, isFalse);
      expect(next.selectedBookIds, isEmpty);
      expect(next.selectedGroupIds, isEmpty);
    });
  });

  group('withBookSelectionToggled', () {
    test('未在多选时不改变状态', () {
      final state = buildState();
      final next = withBookSelectionToggled(state, 1);

      expect(next, same(state));
    });

    test('切换选中与取消选中', () {
      final state = buildState(isSelectionMode: true);

      final selected = withBookSelectionToggled(state, 2);
      expect(selected.selectedBookIds, {2});

      final unselected = withBookSelectionToggled(selected, 2);
      expect(unselected.selectedBookIds, isEmpty);
    });
  });

  group('withAllBooksSelected', () {
    test('选中当前列表的全部书籍并进入多选', () {
      final next = withAllBooksSelected(buildState(bookIds: [3, 4, 5]));

      expect(next.selectedBookIds, {3, 4, 5});
      expect(next.selectedGroupIds, isEmpty);
      expect(next.isSelectionMode, isTrue);
    });
  });

  group('withSelectionCleared', () {
    test('清空已选但保持多选模式', () {
      final next = withSelectionCleared(
        buildState(isSelectionMode: true, selected: {1}),
      );

      expect(next.selectedBookIds, isEmpty);
      expect(next.isSelectionMode, isTrue);
    });
  });
}
