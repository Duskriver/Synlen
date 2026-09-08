import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';

import 'reader_style_bottom_sheet.dart';

/// 页码显示：当前页/总页；总数为 0 时显示 0/0，当前页越界时收敛到范围内。
String formatPageIndicator(int current, int total) {
  if (total == 0) {
    return '0/0';
  }
  final clamped = current.clamp(1, total);
  return '$clamped/$total';
}

/// 阅读器底部控制条：目录入口、上一页/下一页（长按连续翻）、样式面板入口。
class ReaderBottomBar extends StatefulWidget {
  const ReaderBottomBar({
    super.key,
    required this.showControls,
    required this.themeData,
    required this.chapterLabel,
    required this.pageLabel,
    required this.canTurnLeft,
    required this.canTurnRight,
    required this.onTapLeft,
    required this.onTapRight,
    required this.onLongPressLeft,
    required this.onLongPressRight,
    required this.onOpenDrawer,
    required this.onToggleStyleDrawer,
    required this.bottomInset,
  });

  final bool showControls;
  final ThemeData themeData;
  final String chapterLabel;
  final String? pageLabel;
  final bool canTurnLeft;
  final bool canTurnRight;
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;
  final VoidCallback onLongPressLeft;
  final VoidCallback onLongPressRight;
  final VoidCallback onOpenDrawer;
  final void Function(bool show) onToggleStyleDrawer;
  final double bottomInset;

  @override
  State<ReaderBottomBar> createState() => _ReaderBottomBarState();
}

class _ReaderBottomBarState extends State<ReaderBottomBar> {
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeData = widget.themeData;
    final showControls = widget.showControls;
    final chapterLabel = widget.chapterLabel;
    final pageLabel = widget.pageLabel;
    final canTurnLeft = widget.canTurnLeft;
    final canTurnRight = widget.canTurnRight;
    final onTapLeft = widget.onTapLeft;
    final onTapRight = widget.onTapRight;
    final onLongPressLeft = widget.onLongPressLeft;
    final onLongPressRight = widget.onLongPressRight;
    final onOpenDrawer = widget.onOpenDrawer;
    final onToggleStyleDrawer = widget.onToggleStyleDrawer;
    final bottomInset = widget.bottomInset;

    return AnimatedPositioned(
      duration: const Duration(
        milliseconds: AppTheme.defaultAnimationDurationMs,
      ),
      curve: Curves.easeInOut,
      bottom: showControls ? 0 : -(AppTheme.kBottomAppBarHeight + bottomInset),
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(
          milliseconds: AppTheme.defaultAnimationDurationMs,
        ),
        opacity: showControls ? 1.0 : 0.0,
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          decoration: BoxDecoration(
            color: themeData.colorScheme.surfaceContainer,
          ),
          constraints: BoxConstraints(
            maxHeight: AppTheme.kBottomAppBarHeight + bottomInset,
            minHeight: AppTheme.kBottomAppBarHeight + bottomInset,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.list_outlined),
                onPressed: onOpenDrawer,
                color: themeData.colorScheme.onSurface,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onLongPressStart: canTurnLeft
                        ? (_) {
                            onLongPressLeft();
                            _longPressTimer = Timer.periodic(
                              const Duration(milliseconds: 500),
                              (timer) {
                                onLongPressLeft();
                              },
                            );
                          }
                        : null,
                    onLongPressEnd: (_) {
                      _longPressTimer?.cancel();
                    },
                    onLongPressCancel: () {
                      _longPressTimer?.cancel();
                    },
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_outlined),
                      onPressed: canTurnLeft ? onTapLeft : null,
                      onLongPress: null,
                      disabledColor: themeData.disabledColor,
                      color: themeData.colorScheme.onSurface,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Visibility(
                            visible: false,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: Text(
                              '0' * (2 * 4 + 1),
                              style: themeData.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            chapterLabel,
                            style: themeData.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (pageLabel != null)
                        Text(
                          pageLabel,
                          style: themeData.textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  GestureDetector(
                    onLongPressStart: canTurnRight
                        ? (_) {
                            onLongPressRight();
                            _longPressTimer = Timer.periodic(
                              const Duration(milliseconds: 500),
                              (timer) {
                                onLongPressRight();
                              },
                            );
                          }
                        : null,
                    onLongPressEnd: (_) {
                      _longPressTimer?.cancel();
                    },
                    onLongPressCancel: () {
                      _longPressTimer?.cancel();
                    },
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_outlined),
                      onPressed: canTurnRight ? onTapRight : null,
                      onLongPress: null,
                      disabledColor: themeData.disabledColor,
                      color: themeData.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.brush_outlined),
                onPressed: () async {
                  onToggleStyleDrawer(true);
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) {
                      return Consumer(
                        builder: (context, ref, child) {
                          final currentSettings = ref.watch(
                            readerSettingsProvider,
                          );
                          final currentEpubTheme = currentSettings.toEpubTheme(
                            context,
                          );
                          final activeTheme = AppTheme.buildTheme(
                            currentEpubTheme.colorScheme,
                          );

                          return Theme(
                            data: activeTheme,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    activeTheme.colorScheme.surfaceContainerLow,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(28),
                                ),
                              ),
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.sizeOf(context).height * 0.75,
                              ),
                              child: SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Center(
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          top: 24,
                                          bottom: 16,
                                        ),
                                        height: 4,
                                        width: 32,
                                        decoration: BoxDecoration(
                                          color: activeTheme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Flexible(
                                      child: ReaderStyleBottomSheet(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    barrierColor: themeData.colorScheme.scrim.withAlpha(
                      themeData.brightness == Brightness.dark ? 150 : 80,
                    ),
                    scrollControlDisabledMaxHeightRatio: 0.75,
                    constraints: const BoxConstraints(
                      maxWidth: double.infinity,
                    ),
                  );
                  onToggleStyleDrawer(false);
                },
                color: themeData.colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
