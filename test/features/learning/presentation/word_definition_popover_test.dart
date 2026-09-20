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
  test('中间词下方够高时仍向下，左右边缘不越界', () {
    for (final x in [0.0, 370.0]) {
      final placement = WordPopoverPlacement(
        anchor: Rect.fromLTWH(x, 430, 30, 24),
        viewport: viewport,
      );
      expect(placement.below, isTrue);
      expect(placement.left, greaterThanOrEqualTo(viewport.left));
      expect(
        placement.left + placement.width,
        lessThanOrEqualTo(viewport.right),
      );
      expect(
        placement.position(Size(placement.width, placement.height)).dy,
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
    expect(placement.height, 315);
  });

  test('卡片固定为安全视口高度的 35%，不足时限制到可用一侧', () {
    const normal = WordPopoverPlacement(
      anchor: Rect.fromLTWH(100, 60, 50, 24),
      viewport: viewport,
    );
    expect(normal.height, 259);
    const compact = WordPopoverPlacement(
      anchor: Rect.fromLTWH(20, 30, 50, 50),
      viewport: Rect.fromLTWH(0, 0, 200, 100),
    );
    expect(compact.below, isFalse);
    expect(compact.height, 16);
    expect(compact.position(Size(compact.width, compact.height)).dy, 0);
  });

  testWidgets('显式空片段列表不把包围框当作词标记', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WordDefinitionPopover(
            anchorRect: Rect.fromLTWH(100, 100, 200, 50),
            wordRects: [],
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('word-popover')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('word-selection-highlight')),
      findsNothing,
    );
  });
}
