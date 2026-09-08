import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/shelf_book_sort_by.dart';

/// How densely books are shown in the grid.
enum ViewMode { compact, relaxed }

/// State for bookshelf view (sorting, grouping, selection)
class BookshelfState {
  final List<ShelfBook> books;
  final ShelfBookSortBy sortBy;
  final ViewMode viewMode;
  final int? currentGroupId; // Navigation: which folder we're inside
  final int?
  filterGroupId; // Filter: show books from specific group (null = all)
  final Set<int> selectedBookIds;
  final Set<int> selectedGroupIds;
  final bool isSelectionMode;
  final List<ShelfGroup> availableGroups;
  final Map<int?, List<ShelfBook>> cachedBooks;
  // Note: cacheOrder (LRU eviction order) is managed internally by
  // BookshelfTabCache and is *not* part of the UI state.

  BookshelfState.bookshelfState({
    required this.books,
    this.sortBy = ShelfBookSortBy.recentlyAdded,
    this.viewMode = ViewMode.relaxed,
    this.currentGroupId,
    this.filterGroupId,
    this.selectedBookIds = const {},
    this.selectedGroupIds = const {},
    this.isSelectionMode = false,
    this.availableGroups = const [],
    this.cachedBooks = const {},
  });

  BookshelfState copyWith({
    List<ShelfBook>? books,
    ShelfBookSortBy? sortBy,
    ViewMode? viewMode,
    int? currentGroupId,
    int? filterGroupId,
    Set<int>? selectedBookIds,
    Set<int>? selectedGroupIds,
    bool? isSelectionMode,
    List<ShelfGroup>? availableGroups,
    Map<int?, List<ShelfBook>>? cachedBooks,
    bool clearGroup = false,
    bool clearFilter = false,
  }) {
    return BookshelfState.bookshelfState(
      books: books ?? this.books,
      sortBy: sortBy ?? this.sortBy,
      viewMode: viewMode ?? this.viewMode,
      currentGroupId: clearGroup
          ? null
          : (currentGroupId ?? this.currentGroupId),
      filterGroupId: clearFilter ? null : (filterGroupId ?? this.filterGroupId),
      selectedBookIds: selectedBookIds ?? this.selectedBookIds,
      selectedGroupIds: selectedGroupIds ?? this.selectedGroupIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      availableGroups: availableGroups ?? this.availableGroups,
      cachedBooks: cachedBooks ?? this.cachedBooks,
    );
  }

  int get selectedCount => selectedBookIds.length + selectedGroupIds.length;
  bool get hasSelection => selectedCount > 0;
}
