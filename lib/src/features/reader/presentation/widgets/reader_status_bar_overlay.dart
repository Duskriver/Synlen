import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:synlen/src/core/theme/app_theme.dart';

/// 阅读区底部的状态栏浮层：左侧章节 / 目录标题，右侧页码。
///
/// 内容由渲染器通过 [ValueListenable] 推送，避免整棵渲染树重建。
class ReaderStatusBarOverlay extends StatelessWidget {
  const ReaderStatusBarOverlay({
    super.key,
    required this.leftContent,
    required this.rightContent,
    required this.isLoading,
    required this.shouldShowWebView,
  });

  final ValueListenable<String> leftContent;
  final ValueListenable<String> rightContent;
  final bool isLoading;
  final bool shouldShowWebView;

  bool get _visible => !isLoading && shouldShowWebView;

  @override
  Widget build(BuildContext context) {
    Widget buildBadge(
      String content,
      bool tabular, {
      TextOverflow overflow = TextOverflow.clip,
    }) {
      return Text(
        content,
        overflow: overflow,
        style: TextStyle(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w500,
          fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
          shadows: [
            Shadow(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.5),
              blurRadius: 1.0,
              offset: Offset.zero,
            ),
          ],
        ),
      );
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.only(left: 32, right: 32, bottom: 8),
        constraints: const BoxConstraints(minHeight: 32, maxHeight: 32),
        child: AnimatedOpacity(
          duration: _visible
              ? const Duration(
                  milliseconds: AppTheme.defaultAnimationDurationMs,
                )
              : Duration.zero,
          curve: Curves.easeOut,
          opacity: _visible ? 1.0 : 0.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: leftContent,
                builder: (context, content, child) {
                  return Flexible(
                    child: buildBadge(
                      content,
                      false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<String>(
                valueListenable: rightContent,
                builder: (context, content, child) {
                  return buildBadge(content, true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
