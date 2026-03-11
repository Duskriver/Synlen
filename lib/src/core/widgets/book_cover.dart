import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lumina/src/core/storage/app_storage.dart';
import 'package:lumina/src/core/theme/app_theme.dart';

/// Book cover widget with gapless playback.
/// Parent should handle clipping with ClipRRect if rounded corners are needed.
class BookCover extends StatelessWidget {
  static const double _coverAspectRatio = 210 / 297;
  final String? relativePath;
  final BorderRadius radius;
  final bool enableBorder;
  final int cacheHeight;
  static const int globalCacheHeight = 900;

  const BookCover({
    super.key,
    required this.relativePath,
    this.radius = BorderRadius.zero,
    this.enableBorder = true,
    this.cacheHeight = globalCacheHeight,
  });

  bool _isWellImageFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
        lowerPath.endsWith('.jpeg') ||
        lowerPath.endsWith('.png') ||
        lowerPath.endsWith('.webp');
  }

  File? _resolveCoverFile() {
    if (relativePath == null || relativePath!.isEmpty) {
      return null;
    }

    if (!_isWellImageFile(relativePath!)) {
      return null;
    }

    try {
      final decodedPath = Uri.decodeFull(relativePath!);
      return File('${AppStorage.documentsPath}$decodedPath');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolveCoverFile();
    if (file == null) {
      return _buildPlaceholder(context);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: enableBorder
            ? Border.all(color: Theme.of(context).dividerColor, width: 1)
            : null,
      ),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        cacheHeight: cacheHeight,
        cacheWidth: (cacheHeight * _coverAspectRatio).round(),
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
          border: enableBorder
              ? Border.all(color: Theme.of(context).dividerColor, width: 1)
              : null,
        ),
        constraints: BoxConstraints(
          maxHeight: cacheHeight.toDouble(),
          maxWidth: cacheHeight.toDouble() * _coverAspectRatio,
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
