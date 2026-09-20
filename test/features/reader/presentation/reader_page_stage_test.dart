import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/presentation/reader_page_stage.dart';

void main() {
  var menus = 0;
  var nativeUps = 0;
  const blank = Offset(206, 776);
  const content = Offset(206, 400);

  Future<void> pumpStage(WidgetTester tester) async {
    menus = nativeUps = 0;
    await tester.binding.setSurfaceSize(const Size(412, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPageStage(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          onBlankTap: () => menus++,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerUp: (_) => nativeUps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  testWidgets('顶部、底部和两侧Flutter留白短点各触发一次菜单', (tester) async {
    await pumpStage(tester);
    for (final point in [
      const Offset(206, 8),
      blank,
      const Offset(8, 400),
      const Offset(404, 400),
    ]) {
      await tester.tapAt(point);
    }
    expect(menus, 4);
    expect(nativeUps, 0);
  });

  testWidgets('正文点词、链接、图片及原生翻页边缘不触发留白菜单', (tester) async {
    await pumpStage(tester);
    for (final point in [
      content,
      const Offset(21, 400),
      const Offset(391, 400),
    ]) {
      await tester.tapAt(point);
    }
    expect(menus, 0);
    expect(nativeUps, 3);
  });

  testWidgets('留白滑动后移回起点也不触发菜单', (tester) async {
    await pumpStage(tester);
    final gesture = await tester.startGesture(blank);
    await gesture.moveBy(const Offset(11, 0));
    await gesture.moveTo(blank);
    await gesture.up();
    expect(menus, 0);
  });

  testWidgets('留白长按和取消不触发菜单', (tester) async {
    await pumpStage(tester);
    final held = await tester.startGesture(blank);
    await held.up(timeStamp: const Duration(milliseconds: 550));
    final cancelled = await tester.startGesture(blank);
    await cancelled.cancel();
    expect(menus, 0);
  });

  for (final secondPoint in [blank, content]) {
    testWidgets('第二指位于$secondPoint时取消留白菜单，后续单点仍可用', (tester) async {
      await pumpStage(tester);
      final first = await tester.startGesture(blank, pointer: 1);
      final second = await tester.startGesture(secondPoint, pointer: 2);
      await first.up();
      await second.up();
      expect(menus, 0);
      await tester.tapAt(blank);
      expect(menus, 1);
    });
  }
}
