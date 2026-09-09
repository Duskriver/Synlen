import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/book_actions.dart';
import '../../application/bookshelf_notifier.dart';
import '../../domain/book_views.dart';
import '../../../../../l10n/app_localizations.dart';
import '../widgets/book_grid_item.dart';

/// 书架网格：空态提示、两种视图模式的网格参数与点击 / 长按语义。
class LibraryItemsGrid extends ConsumerWidget {
  const LibraryItemsGrid({super.key, required this.state, required this.books});

  final BookshelfState state;
  final List<ShelfBookView> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (books.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noItemsInCategory,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      sliver: SliverGrid(
        gridDelegate: switch (state.viewMode) {
          ViewMode.relaxed => const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180.0,
            childAspectRatio: 0.55,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          ViewMode.compact => const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120.0,
            childAspectRatio: 0.68,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
        },
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final book = books[index];
            return BookGridItem(
              book: book,
              isSelected: state.selectedBookIds.contains(book.id),
              isSelectionMode: state.isSelectionMode,
              viewMode: state.viewMode,
              onTap: () {
                if (state.isSelectionMode) {
                  ref
                      .read(bookshelfProvider.notifier)
                      .toggleItemSelection(book.id);
                  return;
                }

                final notifier = ref.read(bookshelfProvider.notifier);
                // 预取详情：路由动画结束时数据已就位，详情页不闪加载态。
                ref.read(bookDetailProvider(book.fileHash));
                context.push('/book/${book.fileHash}').then((_) {
                  notifier.reloadQuietly();
                });
              },
              onLongPress: () {
                if (!state.isSelectionMode) {
                  HapticFeedback.selectionClick();
                  ref.read(bookshelfProvider.notifier).toggleSelectionMode();
                  ref
                      .read(bookshelfProvider.notifier)
                      .toggleItemSelection(book.id);
                }
              },
            );
          },
          childCount: books.length,
          addAutomaticKeepAlives: false,
        ),
      ),
    );
  }
}
