import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import '../../../library/domain/book_views.dart';

import '../../../library/application/bookshelf_notifier.dart';
import '../widgets/library_app_bar.dart';
import '../widgets/library_items_grid.dart';
import '../widgets/library_selection_bar.dart';
import '../widgets/style_bottom_sheet.dart';
import '../../../../../l10n/app_localizations.dart';

/// 书架主视图：顶栏 + 分组标签页 + 多选操作条。
///
/// 只读 [state] 与 [tabController]，动作经回调交回宿主；标签页数量与顺序
/// 由 [BookshelfState.availableGroups] 决定（全部 / 未分组 / 各分组）。
class LibraryTabView extends ConsumerWidget {
  const LibraryTabView({
    super.key,
    required this.state,
    required this.tabController,
    required this.onEditGroup,
    required this.onMoveToGroup,
    required this.onDeleteSelected,
  });

  final BookshelfState state;
  final TabController tabController;
  final void Function(GroupOption group, AppLocalizations l10n) onEditGroup;
  final VoidCallback onMoveToGroup;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomStatusBarHeight = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              LibraryAppBar(
                state: state,
                tabController: tabController,
                onSortPressed: () => _showStyleBottomSheet(context, ref),
                onSelectionToggle: () =>
                    ref.read(bookshelfProvider.notifier).toggleSelectionMode(),
                onSelectAll: () =>
                    ref.read(bookshelfProvider.notifier).selectAll(),
                onClearSelection: () =>
                    ref.read(bookshelfProvider.notifier).clearSelection(),
                onEditGroup: onEditGroup,
              ),
            ];
          },
          body: TabBarView(
            controller: tabController,
            physics: state.isSelectionMode
                ? const NeverScrollableScrollPhysics()
                : null,
            children: _buildTabViewChildren(state),
          ),
        ),
        // Slide the selection bar up from below the screen when entering
        // selection mode, and back down when leaving it.
        AnimatedPositioned(
          duration: const Duration(
            milliseconds: AppTheme.defaultAnimationDurationMs,
          ),
          curve: Curves.easeInOut,
          bottom: state.isSelectionMode
              ? 0
              : -(AppTheme.kBottomAppBarHeight + bottomStatusBarHeight),
          left: 0,
          right: 0,
          child: LibrarySelectionBar(
            state: state,
            onMove: onMoveToGroup,
            onDelete: onDeleteSelected,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTabViewChildren(BookshelfState state) {
    final tabs = <Widget>[];

    // "All" tab
    tabs.add(_buildTabContent(state, null));
    tabs.add(_buildTabContent(state, -1));

    // Group tabs
    for (final group in state.availableGroups) {
      tabs.add(_buildTabContent(state, group.id));
    }

    return tabs;
  }

  Widget _buildTabContent(BookshelfState state, int? groupId) {
    final isActiveTab = state.filterGroupId == groupId;
    final booksForTab = isActiveTab ? state.books : state.cachedBooks[groupId];
    if (booksForTab == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    // Use Builder to get the correct context inside NestedScrollView
    return Builder(
      builder: (BuildContext context) {
        final bottomStatusBarHeight = MediaQuery.of(context).padding.bottom;
        return CustomScrollView(
          key: PageStorageKey<String>('tab_$groupId'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            LibraryItemsGrid(state: state, books: booksForTab),
            if (state.isSelectionMode)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: AppTheme.kBottomAppBarHeight + bottomStatusBarHeight,
                ),
              ),
          ],
        );
      },
    );
  }

  void _showStyleBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SizedBox(
        width: double.infinity,
        child: StyleBottomSheet(
          currentSort: state.sortBy,
          onSortSelected: (sortBy) {
            ref.read(bookshelfProvider.notifier).changeSortOrder(sortBy);
            Navigator.pop(context);
          },
          currentViewMode: state.viewMode,
          onViewModeSelected: (mode) {
            ref.read(bookshelfProvider.notifier).changeViewMode(mode);
            Navigator.pop(context);
          },
        ),
      ),
      scrollControlDisabledMaxHeightRatio: 0.75,
      constraints: const BoxConstraints(maxWidth: double.infinity),
    );
  }
}
