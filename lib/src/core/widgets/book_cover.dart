import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/theme/app_theme.dart';

import '../providers/cover_file_provider.dart';

/// Book cover widget with Riverpod-based caching and gapless playback.
/// Parent should handle clipping with ClipRRect if rounded corners are needed.
class BookCover extends ConsumerWidget {
  static const double _coverAspectRatio = 210 / 297;
  static const int _cacheHeight = 900;

  final String? relativePath;
  final BorderRadius radius;

  const BookCover({
    super.key,
    required this.relativePath,
    this.radius = BorderRadius.zero,
  });

  bool _isWellImageFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverFileAsync = ref.watch(coverFileProvider(relativePath));
    if (!_isWellImageFile(relativePath ?? '')) {
      return _buildPlaceholder(context);
    }

    return coverFileAsync.when(
      loading: () => _buildPlaceholder(context, showIcon: false),
      error: (error, stack) => _buildPlaceholder(context, showIcon: false),
      data: (file) {
        if (file == null) {
          return _buildPlaceholder(context);
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: radius,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          ),
          child: Image.file(
            file,
            fit: BoxFit.cover,
            cacheHeight: _cacheHeight,
            cacheWidth: (_cacheHeight * _coverAspectRatio).round(),
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                return child;
              }

              return AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: const Duration(
                  milliseconds: AppTheme.defaultLongAnimationDurationMs,
                ),
                curve: Curves.easeOut,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(context, showIcon: false);
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, {bool showIcon = true}) {
    return AspectRatio(
      aspectRatio: _coverAspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        constraints: BoxConstraints(
          maxHeight: _cacheHeight.toDouble(),
          maxWidth: _cacheHeight.toDouble() * _coverAspectRatio,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!showIcon) {
              return const SizedBox.shrink();
            }
            final maxSize = math.min(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final iconSize = maxSize * 0.35;
            return Center(
              child: Icon(
                Icons.menu_book_outlined,
                size: iconSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
      ),
    );
  }
}
