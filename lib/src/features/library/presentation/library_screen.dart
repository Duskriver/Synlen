import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/bookshelf_notifier.dart';
import '../../../../l10n/app_localizations.dart';
import 'mixins/library_actions_mixin.dart';
import 'widgets/expandable_fab.dart';
import 'widgets/library_tab_view.dart';

/// Library Screen - Displays user's book collection with advanced bookshelf features
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with TickerProviderStateMixin, LibraryActionsMixin {
  TabController? _tabController;
  bool _isUpdatingFromState = false;
  int _lastTabIndex = 0;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _initializeTabController(BookshelfState state) {
    final tabCount =
        2 + state.availableGroups.length; // All + Uncategorized + groups

    if (_tabController == null || _tabController!.length != tabCount) {
      final previousController = _tabController;
      previousController?.removeListener(_handleTabChange);
      _tabController = TabController(
        length: tabCount,
        vsync: this,
        initialIndex: _getTabIndexFromState(state),
      );
      _lastTabIndex = _tabController!.index;
      _tabController!.addListener(_handleTabChange);
      if (previousController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          previousController.dispose();
        });
      }
    }
  }

  int _getTabIndexFromState(BookshelfState state) {
    if (state.filterGroupId == -1) return 1;
    if (state.filterGroupId == null) return 0;
    final index = state.availableGroups.indexWhere(
      (g) => g.id == state.filterGroupId,
    );
    return index == -1 ? 0 : index + 2;
  }

  void _handleTabChange() {
    if (_tabController == null || _isUpdatingFromState) return;
    final newIndex = _tabController!.index;
    if (newIndex == _lastTabIndex) return;
    _lastTabIndex = newIndex;

    final state = ref.read(bookshelfProvider).value;
    if (state == null) return;

    if (newIndex == 0) {
      ref.read(bookshelfProvider.notifier).filterByGroup(null);
      return;
    }

    if (newIndex == 1) {
      ref.read(bookshelfProvider.notifier).filterByGroup(-1);
      return;
    }

    final newGroupId = state.availableGroups[newIndex - 2].id;
    if (state.filterGroupId != newGroupId) {
      ref.read(bookshelfProvider.notifier).filterByGroup(newGroupId);
    }
  }

  void _syncTabIndexWithState(BookshelfState state) {
    if (_tabController == null) return;

    final expectedIndex = _getTabIndexFromState(state);
    if (_tabController!.index != expectedIndex) {
      _isUpdatingFromState = true;
      _lastTabIndex = expectedIndex;
      _tabController!.animateTo(expectedIndex);
      Future.delayed(const Duration(milliseconds: 100), () {
        _isUpdatingFromState = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final secondaryAnimation =
        route?.secondaryAnimation ?? const AlwaysStoppedAnimation(0.0);

    // AbsorbPointer to prevent interactions during transition
    return AnimatedBuilder(
      animation: secondaryAnimation,
      builder: (context, child) {
        final isTransitioning =
            secondaryAnimation.value > 0.0 && secondaryAnimation.value < 1.0;

        return AbsorbPointer(absorbing: isTransitioning, child: child);
      },
      child: _buildContentWidget(context),
    );
  }

  Widget _buildContentWidget(BuildContext context) {
    final bookshelfState = ref.watch(bookshelfProvider);

    final state = bookshelfState.value;
    final isSelectionMode = state?.isSelectionMode ?? false;

    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (isSelectionMode) {
          ref.read(bookshelfProvider.notifier).toggleSelectionMode();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: bookshelfState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, stack) => Center(
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.errorLoadingLibrary(error.toString()),
                ),
              ),
              data: (state) {
                _initializeTabController(state);
                _syncTabIndexWithState(state);
                final tabController = _tabController;
                if (tabController == null) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                return LibraryTabView(
                  state: state,
                  tabController: tabController,
                  onEditGroup: (group, l10n) =>
                      showEditGroupDialog(context, ref, group, l10n),
                  onMoveToGroup: () => showMoveToGroup(context, ref, state),
                  onDeleteSelected: () => confirmDelete(context, ref),
                );
              },
            ),
            floatingActionButton: _buildFAB(context, ref, state),
          ),
          if (isSelectingFiles)
            Positioned.fill(
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildFAB(
    BuildContext context,
    WidgetRef ref,
    BookshelfState? state,
  ) {
    if (state?.isSelectionMode ?? false) {
      return null;
    }

    ExpandableFabChild buildFabChild(
      IconData icon,
      String label,
      VoidCallback onTap,
    ) {
      return ExpandableFabChild(
        icon: icon,
        label: label,
        onTap: onTap,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      );
    }

    return ExpandableFab(
      icon: Icons.add_outlined,
      activeIcon: Icons.close_outlined,
      spaceBetweenChildren: 8,
      children: [
        buildFabChild(
          Icons.file_present_outlined,
          AppLocalizations.of(context)!.importFiles,
          () => _importFiles(context, ref),
        ),
        buildFabChild(
          Icons.folder_open_outlined,
          AppLocalizations.of(context)!.importFromFolder,
          () => _scanFolder(context, ref),
        ),
        buildFabChild(
          Icons.settings_backup_restore_outlined,
          AppLocalizations.of(context)!.restoreFromBackup,
          () => handleRestoreBackup(context, ref),
        ),
      ],
    );
  }

  // Placeholder method for scanning folder
  void _scanFolder(BuildContext context, WidgetRef ref) {
    handleScanFolder(context, ref);
  }

  // Placeholder method for importing files
  void _importFiles(BuildContext context, WidgetRef ref) {
    handleImportFiles(context, ref);
  }
}
