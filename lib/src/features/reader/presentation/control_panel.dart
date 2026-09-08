import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/features/reader/application/page_navigation.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'widgets/reader_bottom_bar.dart';

class ControlPanel extends ConsumerStatefulWidget {
  final bool showControls;
  final String title;
  final int currentSpineItemIndex;
  final int totalSpineItems;
  final int currentPageInChapter;
  final int totalPagesInChapter;
  final int direction;
  final VoidCallback onBack;
  final VoidCallback onOpenDrawer;
  final VoidCallback onPreviousPage;
  final VoidCallback onFirstPage;
  final VoidCallback onNextPage;
  final VoidCallback onLastPage;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final Function(bool show) onToggleStyleDrawer;

  const ControlPanel({
    super.key,
    required this.showControls,
    required this.title,
    required this.currentSpineItemIndex,
    required this.totalSpineItems,
    required this.currentPageInChapter,
    required this.totalPagesInChapter,
    required this.direction,
    required this.onBack,
    required this.onOpenDrawer,
    required this.onPreviousPage,
    required this.onFirstPage,
    required this.onNextPage,
    required this.onLastPage,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onToggleStyleDrawer,
  });

  bool get isVertical => direction == 1;

  @override
  ConsumerState<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends ConsumerState<ControlPanel> {
  /// 能否向指定方向翻页：越出全书首 / 末页时为 false，与 [ReaderNavigator] 同一判定。
  bool _canTurn(bool isNext) {
    return resolvePageTurnBoundary(
          isNext: isNext,
          currentPage: widget.currentPageInChapter,
          totalPages: widget.totalPagesInChapter,
          currentSpineIndex: widget.currentSpineItemIndex,
          spineLength: widget.totalSpineItems,
        ) ==
        PageTurnBoundary.ok;
  }

  void _handlePreviousChapter() {
    if (widget.currentPageInChapter == 0 && widget.currentSpineItemIndex > 0) {
      HapticFeedback.selectionClick();
      widget.onPreviousChapter();
    } else if (widget.currentPageInChapter > 0) {
      HapticFeedback.selectionClick();
      widget.onFirstPage();
    }
  }

  void _handleNextChapter() {
    if (widget.currentSpineItemIndex < widget.totalSpineItems - 1) {
      HapticFeedback.selectionClick();
      widget.onNextChapter();
    } else if (widget.currentSpineItemIndex == widget.totalSpineItems - 1 &&
        widget.currentPageInChapter < widget.totalPagesInChapter - 1) {
      HapticFeedback.selectionClick();
      widget.onLastPage();
    }
  }

  void _handleLongPressLeft() {
    if (widget.isVertical) {
      _handleNextChapter();
    } else {
      _handlePreviousChapter();
    }
  }

  void _handleLongPressRight() {
    if (widget.isVertical) {
      _handlePreviousChapter();
    } else {
      _handleNextChapter();
    }
  }

  void _handleTapLeft() {
    if (widget.isVertical) {
      widget.onNextPage();
    } else {
      widget.onPreviousPage();
    }
  }

  void _handleTapRight() {
    if (widget.isVertical) {
      widget.onPreviousPage();
    } else {
      widget.onNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final epubTheme = settings.toEpubTheme(context);
    final themeData = AppTheme.buildTheme(epubTheme.colorScheme);

    final topStatusBarHeight = MediaQuery.of(context).padding.top;
    final bottomStatusBarHeight = MediaQuery.of(context).padding.bottom;
    return Theme(
      data: themeData,
      child: Stack(
        children: [
          // Top Bar
          AnimatedPositioned(
            duration: const Duration(
              milliseconds: AppTheme.defaultAnimationDurationMs,
            ),
            curve: Curves.easeInOut,
            top: widget.showControls
                ? 0
                : -(AppTheme.kTopAppBarHeight + topStatusBarHeight),
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(
                milliseconds: AppTheme.defaultAnimationDurationMs,
              ),
              opacity: widget.showControls ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: themeData.colorScheme.surfaceContainer,
                ),
                child: AppBar(
                  backgroundColor: themeData.colorScheme.surfaceContainer,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_outlined),
                    onPressed: widget.onBack,
                  ),
                  title: Text(
                    widget.title,
                    style: themeData.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),

          ReaderBottomBar(
            showControls: widget.showControls,
            themeData: themeData,
            chapterLabel: formatPageIndicator(
              widget.currentSpineItemIndex + 1,
              widget.totalSpineItems,
            ),
            pageLabel: widget.totalPagesInChapter > 1
                ? formatPageIndicator(
                    widget.currentPageInChapter + 1,
                    widget.totalPagesInChapter,
                  )
                : null,
            canTurnLeft: _canTurn(widget.isVertical),
            canTurnRight: _canTurn(!widget.isVertical),
            onTapLeft: _handleTapLeft,
            onTapRight: _handleTapRight,
            onLongPressLeft: _handleLongPressLeft,
            onLongPressRight: _handleLongPressRight,
            onOpenDrawer: widget.onOpenDrawer,
            onToggleStyleDrawer: widget.onToggleStyleDrawer,
            bottomInset: bottomStatusBarHeight,
          ),
        ],
      ),
    );
  }
}
