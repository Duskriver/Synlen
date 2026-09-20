import 'package:flutter/material.dart';

import 'widgets/reader_bottom_bar.dart';

/// 阅读控制条显示章节和全书百分比；定位与分页由 Readium 负责。
class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.showControls,
    required this.title,
    required this.chapterIndex,
    required this.chapterCount,
    required this.progress,
    required this.ready,
    required this.rtl,
    required this.onBack,
    required this.onOpenDrawer,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onToggleStyleDrawer,
  });
  final bool showControls;
  final String title;
  final int chapterIndex;
  final int chapterCount;
  final double progress;
  final bool ready;
  final bool rtl;
  final VoidCallback onBack;
  final VoidCallback onOpenDrawer;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<bool> onToggleStyleDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        if (showControls)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: theme.colorScheme.surfaceContainer,
              leading: BackButton(onPressed: onBack),
              title: Text(
                title,
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ReaderBottomBar(
          showControls: showControls,
          themeData: theme,
          chapterLabel: formatPageIndicator(chapterIndex + 1, chapterCount),
          pageLabel: '${(progress * 100).toStringAsFixed(1)}%',
          canTurnLeft: ready,
          canTurnRight: ready,
          onTapLeft: rtl ? onNextPage : onPreviousPage,
          onTapRight: rtl ? onPreviousPage : onNextPage,
          onLongPressLeft: rtl ? onNextChapter : onPreviousChapter,
          onLongPressRight: rtl ? onPreviousChapter : onNextChapter,
          onOpenDrawer: onOpenDrawer,
          onToggleStyleDrawer: onToggleStyleDrawer,
          bottomInset: MediaQuery.paddingOf(context).bottom,
        ),
      ],
    );
  }
}
