import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 锚点与安全区均相对当前 overlay；词标记与卡片共享路由生命周期。
class WordDefinitionPopover extends StatelessWidget {
  const WordDefinitionPopover({
    super.key,
    required this.anchorRect,
    this.wordRects,
    required this.child,
  });

  final Rect anchorRect;
  final List<Rect>? wordRects;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Rect.fromLTRB(
          media.padding.left + 12,
          media.padding.top + 12,
          constraints.maxWidth - media.padding.right - 12,
          constraints.maxHeight -
              math.max(media.padding.bottom, media.viewInsets.bottom) -
              12,
        );
        final layout = WordPopoverPlacement(
          anchor: anchorRect,
          viewport: viewport,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final rect in wordRects ?? [anchorRect])
              Positioned.fromRect(
                rect: rect.inflate(2),
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey('word-selection-highlight'),
                    decoration: BoxDecoration(
                      color: colors.tertiary.withValues(alpha: 0.24),
                      border: Border.all(
                        color: colors.tertiary.withValues(alpha: 0.65),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            CustomSingleChildLayout(
              delegate: _WordPopoverDelegate(layout),
              child: CustomPaint(
                painter: _WordPopoverPainter(
                  placement: layout,
                  color: colors.surfaceContainerHigh,
                  shadow: colors.shadow.withValues(alpha: 0.42),
                  outline: colors.outlineVariant.withValues(alpha: 0.7),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Material(
                    key: const ValueKey('word-popover'),
                    color: Colors.transparent,
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 卡片固定占安全视口高度的 35%；极小视口才缩到目标词一侧的可用空间。
class WordPopoverPlacement {
  const WordPopoverPlacement({required this.anchor, required this.viewport});

  final Rect anchor;
  final Rect viewport;
  static const _gap = 14.0;
  double get _preferredHeight => viewport.height * 0.35;

  double get width => math.min(380, math.max(0, viewport.width * 0.84));
  double get _above => math.max(0, anchor.top - viewport.top - _gap);
  double get _below => math.max(0, viewport.bottom - anchor.bottom - _gap);
  bool get below =>
      _below >= _preferredHeight ||
      (_above < _preferredHeight && _below >= _above);
  double get height => math.min(_preferredHeight, below ? _below : _above);
  double get left => (anchor.center.dx - width / 2).clamp(
    viewport.left,
    viewport.right - width,
  );
  double get arrowX =>
      (anchor.center.dx - left).clamp(28, math.max(28, width - 28));
  Offset position(Size size) => Offset(
    left,
    below ? anchor.bottom + _gap : anchor.top - _gap - size.height,
  );
}

class _WordPopoverDelegate extends SingleChildLayoutDelegate {
  _WordPopoverDelegate(this.placement);
  final WordPopoverPlacement placement;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        minWidth: placement.width,
        maxWidth: placement.width,
        minHeight: placement.height,
        maxHeight: placement.height,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      placement.position(childSize);

  @override
  bool shouldRelayout(_WordPopoverDelegate oldDelegate) =>
      placement.anchor != oldDelegate.placement.anchor ||
      placement.viewport != oldDelegate.placement.viewport;
}

class _WordPopoverPainter extends CustomPainter {
  _WordPopoverPainter({
    required this.placement,
    required this.color,
    required this.shadow,
    required this.outline,
  });
  final WordPopoverPlacement placement;
  final Color color;
  final Color shadow;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(26)),
      );
    final x = placement.arrowX;
    final edge = placement.below ? 0.0 : size.height;
    final tip = edge + (placement.below ? -9.0 : 9.0);
    final triangle = Path()
      ..moveTo(x - 10, edge)
      ..lineTo(x, tip)
      ..lineTo(x + 10, edge)
      ..close();
    final shape = Path.combine(PathOperation.union, path, triangle);
    canvas.drawShadow(shape, shadow, 18, true);
    canvas.drawPath(shape, Paint()..color = color);
    canvas.drawPath(
      shape,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WordPopoverPainter oldDelegate) =>
      color != oldDelegate.color ||
      shadow != oldDelegate.shadow ||
      outline != oldDelegate.outline ||
      placement.arrowX != oldDelegate.placement.arrowX ||
      placement.below != oldDelegate.placement.below;
}
