import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/features/reader/presentation/widgets/reader_bottom_bar.dart';

void main() {
  group('formatPageIndicator', () {
    test('总页数为 0 时显示 0/0', () {
      expect(formatPageIndicator(1, 0), '0/0');
    });

    test('当前页越界时收敛到范围内', () {
      expect(formatPageIndicator(9, 5), '5/5');
      expect(formatPageIndicator(0, 5), '1/5');
    });

    test('正常显示当前页/总页', () {
      expect(formatPageIndicator(2, 10), '2/10');
    });
  });

  group('ReaderBottomBar', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required bool canTurnLeft,
      required bool canTurnRight,
      String? pageLabel = '2/10',
      VoidCallback? onTapLeft,
      VoidCallback? onTapRight,
      VoidCallback? onLongPressLeft,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  ReaderBottomBar(
                    showControls: true,
                    themeData: AppTheme.buildTheme(
                      ThemeData.light().colorScheme,
                    ),
                    chapterLabel: '3/12',
                    pageLabel: pageLabel,
                    canTurnLeft: canTurnLeft,
                    canTurnRight: canTurnRight,
                    onTapLeft: onTapLeft ?? () {},
                    onTapRight: onTapRight ?? () {},
                    onLongPressLeft: onLongPressLeft ?? () {},
                    onLongPressRight: () {},
                    onOpenDrawer: () {},
                    onToggleStyleDrawer: (_) {},
                    bottomInset: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('显示章节与页码标签', (tester) async {
      await pumpBar(tester, canTurnLeft: true, canTurnRight: true);

      expect(find.text('3/12'), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
    });

    testWidgets('pageLabel 为空时不显示章内页码', (tester) async {
      await pumpBar(
        tester,
        canTurnLeft: true,
        canTurnRight: true,
        pageLabel: null,
      );

      expect(find.text('3/12'), findsOneWidget);
      expect(find.textContaining('/10'), findsNothing);
    });

    testWidgets('不能翻页时对应按钮禁用', (tester) async {
      await pumpBar(tester, canTurnLeft: false, canTurnRight: true);

      final left = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left_outlined),
      );
      final right = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_outlined),
      );

      expect(left.onPressed, isNull);
      expect(right.onPressed, isNotNull);
    });

    testWidgets('点击左右按钮触发回调', (tester) async {
      var taps = <String>[];
      await pumpBar(
        tester,
        canTurnLeft: true,
        canTurnRight: true,
        onTapLeft: () => taps.add('left'),
        onTapRight: () => taps.add('right'),
      );

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.chevron_left_outlined),
      );
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.chevron_right_outlined),
      );

      expect(taps, ['left', 'right']);
    });

    testWidgets('长按左键触发一次并随后连续触发', (tester) async {
      var longPresses = 0;
      await pumpBar(
        tester,
        canTurnLeft: true,
        canTurnRight: true,
        onLongPressLeft: () => longPresses++,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(
          find.widgetWithIcon(IconButton, Icons.chevron_left_outlined),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(longPresses, greaterThanOrEqualTo(2));
    });
  });
}
