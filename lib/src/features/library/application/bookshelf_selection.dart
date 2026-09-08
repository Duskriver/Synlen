import 'bookshelf_state.dart';

/// 进入多选模式；已在多选时退出并清空已选。
BookshelfState withSelectionModeToggled(BookshelfState state) {
  if (state.isSelectionMode) {
    return state.copyWith(
      isSelectionMode: false,
      selectedBookIds: {},
      selectedGroupIds: {},
    );
  }
  return state.copyWith(isSelectionMode: true);
}

/// 切换单本书的选中状态；非多选模式时原样返回。
BookshelfState withBookSelectionToggled(BookshelfState state, int bookId) {
  if (!state.isSelectionMode) return state;

  final newSelection = Set<int>.from(state.selectedBookIds);
  if (!newSelection.remove(bookId)) {
    newSelection.add(bookId);
  }
  return state.copyWith(selectedBookIds: newSelection);
}

/// 全选当前列表中的书并进入多选模式；分组不可选（扁平结构）。
BookshelfState withAllBooksSelected(BookshelfState state) {
  return state.copyWith(
    selectedBookIds: state.books.map((book) => book.id).toSet(),
    selectedGroupIds: {},
    isSelectionMode: true,
  );
}

/// 清空已选，保持多选模式开关不变。
BookshelfState withSelectionCleared(BookshelfState state) {
  return state.copyWith(selectedBookIds: {}, selectedGroupIds: {});
}
