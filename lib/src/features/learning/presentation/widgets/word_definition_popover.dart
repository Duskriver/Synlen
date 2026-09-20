import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 锚点与安全区均相对当前 overlay；卡片只占目标词一侧的可用空间。
class WordDefinitionPopover extends StatelessWidget {
  const WordDefinitionPopover({
    super.key,
    required this.anchorRect,
    required this.child,
  });

  final Rect anchorRect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
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
        return CustomSingleChildLayout(
          delegate: _WordPopoverDelegate(layout),
          child: CustomPaint(
            painter: _WordPopoverPainter(
              placement: layout,
              color: Theme.of(context).colorScheme.surface,
              shadow: Theme.of(
                context,
              ).colorScheme.shadow.withValues(alpha: 0.16),
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
        );
      },
    );
  }
}

/// 选择方向时使用固定期望高度，避免流式内容增长导致卡片上下跳动。
class WordPopoverPlacement {
  const WordPopoverPlacement({required this.anchor, required this.viewport});

  final Rect anchor;
  final Rect viewport;
  static const _gap = 14.0;
  static const _preferredHeight = 420.0;

  double get width => math.min(380, math.max(0, viewport.width * 0.84));
  double get _above => math.max(0, anchor.top - viewport.top - _gap);
  double get _below => math.max(0, viewport.bottom - anchor.bottom - _gap);
  bool get below =>
      _below >= _preferredHeight ||
      (_above < _preferredHeight && _below >= _above);
  double get maxHeight => math.min(viewport.height, below ? _below : _above);
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
        maxHeight: placement.maxHeight,
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
  });
  final WordPopoverPlacement placement;
  final Color color;
  final Color shadow;

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
    canvas.drawShadow(shape, shadow, 10, true);
    canvas.drawPath(shape, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_WordPopoverPainter oldDelegate) =>
      color != oldDelegate.color ||
      shadow != oldDelegate.shadow ||
      placement.arrowX != oldDelegate.placement.arrowX ||
      placement.below != oldDelegate.placement.below;
}
