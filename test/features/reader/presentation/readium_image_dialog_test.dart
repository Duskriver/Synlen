import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/reader/presentation/readium_image_dialog.dart';

void main() {
  late Directory directory;
  late File photo;
  late File raster;
  late GlobalKey<NavigatorState> navigator;
  var readerTouches = 0;

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('image-dialog-');
    photo = File('${directory.path}/photo.svg')
      ..writeAsStringSync(
        '<svg xmlns="http://www.w3.org/2000/svg" width="200" height="100">'
        '<rect width="200" height="100" fill="red"/></svg>',
      );
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 200, 100),
      Paint()..color = Colors.red,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 100);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    raster = File('${directory.path}/photo.png')
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
    navigator = GlobalKey<NavigatorState>();
    readerTouches = 0;
  });

  tearDown(() => directory.deleteSync(recursive: true));

  Future<void> openPhoto(WidgetTester tester, {bool svg = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => readerTouches++,
          onPointerUp: (_) => readerTouches++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) =>
          ReadiumImageDialog(url: svg ? photo.path : raster.path, svg: svg),
    );
    await tester.pumpAndSettle();
    final image = find.byType(svg ? SvgPicture : Image);
    for (var attempt = 0; attempt < 100; attempt++) {
      if (tester.getSize(image) == const Size(200, 100)) break;
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(image), const Size(200, 100));
  }

  for (final svg in [true, false]) {
    testWidgets('${svg ? 'SVG' : 'PNG'}图片外点击退出，关闭触摸不会到达阅读页', (tester) async {
      await openPhoto(tester, svg: svg);
      await tester.tapAt(const Offset(20, 560));
      await tester.pumpAndSettle();
      expect(find.byType(ReadiumImageDialog), findsNothing);
      expect(readerTouches, 0);
      await tester.tapAt(const Offset(20, 560));
      expect(readerTouches, 2);
    });
  }

  testWidgets('没有关闭按钮，点击图片保留查看器', (tester) async {
    await openPhoto(tester);
    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.byType(SvgPicture));
    await tester.pumpAndSettle();
    expect(find.byType(ReadiumImageDialog), findsOneWidget);
    expect(readerTouches, 0);
  });

  testWidgets('返回只关闭图片，未结束的手势不触发阅读页', (tester) async {
    await openPhoto(tester);
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(80, 0));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await gesture.up();
    expect(find.byType(ReadiumImageDialog), findsNothing);
    expect(readerTouches, 0);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('留白拖动、长按和取消不会关闭图片或触发阅读页', (tester) async {
    await openPhoto(tester);
    await tester.dragFrom(const Offset(20, 560), const Offset(160, 0));
    await tester.pumpAndSettle();
    await tester.longPressAt(const Offset(20, 560));
    final cancelled = await tester.startGesture(const Offset(20, 560));
    await cancelled.cancel();
    await tester.pumpAndSettle();
    expect(find.byType(ReadiumImageDialog), findsOneWidget);
    expect(readerTouches, 0);
  });

  testWidgets('缩放和平移后按图片的可见边界区分内外点击', (tester) async {
    await openPhoto(tester, svg: false);
    final photoFinder = find.byType(Image);
    final original = tester.getRect(photoFinder);
    final left = await tester.startGesture(
      original.center - const Offset(30, 0),
      pointer: 1,
    );
    final right = await tester.startGesture(
      original.center + const Offset(30, 0),
      pointer: 2,
    );
    await left.moveBy(const Offset(-30, 0));
    await right.moveBy(const Offset(30, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    final enlarged = tester.getRect(photoFinder);
    expect(enlarged.width, greaterThan(original.width));
    await tester.drag(photoFinder, const Offset(100, 0));
    await tester.pumpAndSettle();
    final moved = tester.getRect(photoFinder);
    expect(moved.center.dx, greaterThan(enlarged.center.dx));
    final inside = moved.centerRight - const Offset(10, 0);
    expect(original.contains(inside), isFalse);
    await tester.tapAt(inside);
    await tester.pumpAndSettle();
    expect(find.byType(ReadiumImageDialog), findsOneWidget);
    await tester.tapAt(moved.topCenter - const Offset(0, 20));
    await tester.pumpAndSettle();
    expect(find.byType(ReadiumImageDialog), findsNothing);
    expect(readerTouches, 0);
  });
}
