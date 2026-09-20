import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_popover.dart';

void main() {
  const viewport = Rect.fromLTRB(12, 36, 388, 776);
  test('下方足够时优先下方，底部词改用上方', () {
    final top = WordPopoverPlacement(
      anchor: const Rect.fromLTWH(100, 60, 50, 24),
      viewport: viewport,
    );
    expect(top.below, isTrue);
    expect(top.position(const Size(300, 200)).dy, greaterThan(84));
    final bottom = WordPopoverPlacement(
      anchor: const Rect.fromLTWH(100, 700, 50, 24),
      viewport: viewport,
    );
    expect(bottom.below, isFalse);
    expect(bottom.position(const Size(300, 200)).dy + 200, lessThan(700));
  });
  test('中间词选空间更大的一侧，左右边缘不越界', () {
    for (final x in [0.0, 370.0]) {
      final placement = WordPopoverPlacement(
        anchor: Rect.fromLTWH(x, 430, 30, 24),
        viewport: viewport,
      );
      expect(placement.below, isFalse);
      expect(placement.left, greaterThanOrEqualTo(viewport.left));
      expect(
        placement.left + placement.width,
        lessThanOrEqualTo(viewport.right),
      );
      expect(
        placement.position(Size(placement.width, placement.maxHeight)).dy,
        greaterThanOrEqualTo(viewport.top),
      );
      expect(placement.arrowX, inInclusiveRange(28, placement.width - 28));
    }
  });
  test('平板宽度不超过 380', () {
    const placement = WordPopoverPlacement(
      anchor: Rect.fromLTWH(500, 100, 80, 24),
      viewport: Rect.fromLTWH(0, 0, 1200, 900),
    );
    expect(placement.width, 380);
  });
}
