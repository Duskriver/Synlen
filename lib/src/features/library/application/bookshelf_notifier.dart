import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/shelf_book_sort_by.dart';
import '../data/shelf_book_repository.dart';
import '../data/repositories/shelf_book_repository_provider.dart';
import '../data/services/epub_import_service_provider.dart';
import '../data/services/epub_import_service.dart';
import 'bookshelf_selection.dart';
import 'bookshelf_state.dart';
import 'bookshelf_tab_cache.dart';

export 'bookshelf_state.dart';

part 'bookshelf_notifier.g.dart';

/// Notifier for managing bookshelf operations with dependency injection
@riverpod
class BookshelfNotifier extends _$BookshelfNotifier {
  static const String _sortOrderKey = 'bookshelf_sort_order';
  static const String _viewModeKey = 'bookshelf_view_mode';

  final _tabCache = BookshelfTabCache();

  // Cached SharedPreferences instance, set during build.
  SharedPreferences? _prefs;

  // Access repositories via providers (lazy initialization)
  ShelfBookRepository get _repository => ref.read(shelfBookRepositoryProvider);
  EpubImportService get _importService => ref.read(epubImportServiceProvider);

  @override
  Future<BookshelfState> build() async {
    // Load SharedPreferences and restore the previously saved sort order.
    _prefs = ref.read(sharedPreferencesProvider);
    final savedSortName = _prefs?.getString(_sortOrderKey);
    final savedSort = savedSortName != null
        ? ShelfBookSortBy.values.firstWhere(
            (e) => e.name == savedSortName,
            orElse: () => ShelfBookSortBy.recentlyAdded,
          )
        : ShelfBookSortBy.recentlyAdded;
    final savedViewModeName = _prefs?.getString(_viewModeKey);
    final savedViewMode = savedViewModeName != null
        ? ViewMode.values.firstWhere(
            (e) => e.name == savedViewModeName,
            orElse: () => ViewMode.relaxed,
          )
        : ViewMode.relaxed;
    return await _loadBooks(sortBy: savedSort, viewMode: savedViewMode);
  }

  /// Load folders + books with current filters
  Future<BookshelfState> _loadBooks({
    ShelfBookSortBy? sortBy,
    ViewMode? viewMode,
    int? groupId,
    int? filterGroupId,
    bool clearGroup = false,
    bool clearFilter = false,
  }) async {
    final currentState =
        state.value ?? BookshelfState.bookshelfState(books: []);

    final actualSortBy = sortBy ?? currentState.sortBy;
    final actualViewMode = viewMode ?? currentState.viewMode;
    final actualGroupId = clearGroup
        ? null
        : (groupId ?? currentState.currentGroupId);
    final actualFilterGroupId = clearFilter
        ? null
        : (filterGroupId ?? currentState.filterGroupId);

    // Get group name for filtering
    String? filterGroupName;
    if (actualFilterGroupId != null && actualFilterGroupId != -1) {
      final group = await _repository.getGroupById(actualFilterGroupId);
      filterGroupName = group?.name;
    }

    final shouldFilterByGroup =
        actualFilterGroupId != null || actualGroupId != null;
    final books = await _repository.getBooksSorted(
      sortBy: actualSortBy,
      groupName: actualFilterGroupId == -1 ? null : filterGroupName,
      includeAll: !shouldFilterByGroup,
    );
    final allGroups = await _repository.getGroups();
    final cacheKey = shouldFilterByGroup ? actualFilterGroupId : null;
    final updatedCache = _tabCache.put(cacheKey, books);

    return BookshelfState.bookshelfState(
      books: books,
      sortBy: actualSortBy,
      viewMode: actualViewMode,
      currentGroupId: actualGroupId,
      filterGroupId: actualFilterGroupId,
      availableGroups: allGroups,
      selectedBookIds: currentState.selectedBookIds,
      selectedGroupIds: currentState.selectedGroupIds,
      isSelectionMode: currentState.isSelectionMode,
      cachedBooks: updatedCache,
    );
  }

  /// Change sort order and persist the selection.
  Future<void> changeSortOrder(ShelfBookSortBy sortBy) async {
    // Persist asynchronously – fire and forget, no need to await.
    _prefs?.setString(_sortOrderKey, sortBy.name);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadBooks(sortBy: sortBy));
  }

  /// Change view mode and persist the selection.
  void changeViewMode(ViewMode mode) {
    _prefs?.setString(_viewModeKey, mode.name);
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(viewMode: mode));
  }

  /// Filter by group (null = show all books)
  Future<void> filterByGroup(int? groupId) async {
    state = await AsyncValue.guard(
      () => _loadBooks(filterGroupId: groupId, clearFilter: groupId == null),
    );
  }

  /// Create a new group (flat structure, no nesting)
  Future<int?> createGroup(String name) async {
    final result = await _repository.createGroup(name: name);
    if (result.isLeft()) {
      return null;
    }

    await refresh();

    final newGroupId = result.getRight().toNullable()!;
    return newGroupId;
  }

  /// Toggle selection mode
  void toggleSelectionMode() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(withSelectionModeToggled(currentState));
  }

  /// Toggle item selection
  void toggleItemSelection(ShelfBook book) {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(withBookSelectionToggled(currentState, book.id));
  }

  /// Select all books
  void selectAll() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(withAllBooksSelected(currentState));
  }

  /// Clear selection
  void clearSelection() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(withSelectionCleared(currentState));
  }

  /// Move selected items to a target group (null = root)
  Future<bool> moveSelectedItems(int? targetGroupId) async {
    final currentState = state.value;
    if (currentState == null || !currentState.hasSelection) return false;

    try {
      // Get target group name
      String? targetGroupName;
      if (targetGroupId != null) {
        final group = await _repository.getGroupById(targetGroupId);
        targetGroupName = group?.name;
      }

      if (currentState.selectedBookIds.isNotEmpty) {
        await _repository.moveBooksToGroup(
          bookIds: currentState.selectedBookIds,
          targetGroupName: targetGroupName,
        );
      }

      // Note: Group moving is removed (flat structure)
      // Groups selected will simply be ignored

      // Reload items and clear selection
      state = const AsyncValue.loading();
      final newState = await _loadBooks();
      state = AsyncValue.data(
        newState.copyWith(
          selectedBookIds: {},
          selectedGroupIds: {},
          isSelectionMode: false,
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete selected books
  Future<bool> deleteSelected() async {
    final currentState = state.value;
    if (currentState == null || !currentState.hasSelection) return false;

    try {
      for (final bookId in currentState.selectedBookIds) {
        final book = await _repository.getBookById(bookId);
        if (book == null) {
          return false;
        }

        // Delete using import service (handles files + database)
        final deleteResult = await _importService.deleteBook(book);
        if (deleteResult.isLeft()) {
          return false;
        }
      }

      // Reload items and clear selection
      state = const AsyncValue.loading();
      final newState = await _loadBooks();
      state = AsyncValue.data(
        newState.copyWith(
          selectedBookIds: {},
          selectedGroupIds: {},
          isSelectionMode: false,
        ),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Refresh books
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadBooks());
  }

  Future<bool> reloadQuietly() async {
    if (state.value == null) return true;
    try {
      // Re-use _loadBooks so the filter/sort/cache logic is in one place.
      // Unlike refresh(), we do NOT emit AsyncLoading first, so the UI keeps
      // showing the existing books during the background reload.
      final newState = await _loadBooks();
      state = AsyncValue.data(newState);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renameGroup(int groupId, String name) async {
    if (name.trim().isEmpty) return false;
    try {
      final result = await _repository.updateGroupName(
        groupId: groupId,
        name: name.trim(),
      );
      if (result.isRight()) {
        state = await AsyncValue.guard(() => _loadBooks());
      }
      return result.isRight();
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroup(int groupId) async {
    try {
      final result = await _repository.deleteGroup(groupId: groupId);
      if (result.isLeft()) return false;

      final currentState = state.value;
      final clearFilter = currentState?.filterGroupId == groupId;
      final clearGroup = currentState?.currentGroupId == groupId;
      final newState = await _loadBooks(
        clearFilter: clearFilter,
        clearGroup: clearGroup,
      );
      // Remove the deleted group from the LRU cache.
      state = AsyncValue.data(
        newState.copyWith(cachedBooks: _tabCache.remove(groupId)),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
