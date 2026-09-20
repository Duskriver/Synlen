import 'dart:async';

import 'package:flutter_readium/reader_orientation_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('视口关闭取消尚未开始的旋转校正', (tester) async {
    var calls = 0;
    final alignment = ReaderOrientationAlignment(onError: (_, _) => fail('没有在途请求'));
    alignment.schedule(() async => calls++);
    await tester.pump(const Duration(milliseconds: 200));
    alignment.dispose();
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 0);
    alignment.schedule(() async => calls++);
    await tester.pump(const Duration(milliseconds: 600));
    expect(calls, 0);
  });

  testWidgets('关闭后在途原生取消不回传到后续视口', (tester) async {
    final request = Completer<void>();
    final errors = <Object>[];
    final alignment = ReaderOrientationAlignment(onError: (error, _) => errors.add(error));
    alignment.schedule(() => request.future);
    await tester.pump(const Duration(milliseconds: 500));
    alignment.dispose();
    request.completeError(StateError('native disposed'));
    await tester.pump();
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('仍活动的校正失败回传且连续旋转只执行最后一次', (tester) async {
    final errors = <Object>[];
    var calls = 0;
    final alignment = ReaderOrientationAlignment(onError: (error, _) => errors.add(error));
    alignment.schedule(() async => calls++);
    await tester.pump(const Duration(milliseconds: 200));
    final failure = StateError('native navigation failed');
    alignment.schedule(() async {
      calls++;
      throw failure;
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    expect(errors, [failure]);
    alignment.dispose();
  });
}
