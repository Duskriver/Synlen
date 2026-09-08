import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/application/volume_key_page_turn.dart';

void main() {
  late StreamController<String> events;
  late List<String> calls;
  late bool enabled;

  VolumeKeyPageTurnController buildController() {
    return VolumeKeyPageTurnController(
      events: events.stream,
      enableInterception: () => calls.add('enable'),
      disableInterception: () => calls.add('disable'),
      onPreviousPage: () => calls.add('previous'),
      onNextPage: () => calls.add('next'),
      isEnabled: () => enabled,
    );
  }

  setUp(() {
    events = StreamController<String>.broadcast();
    calls = [];
    enabled = true;
  });

  tearDown(() async {
    await events.close();
  });

  test('禁用时放开拦截且不订阅事件', () async {
    final controller = buildController();

    controller.sync(enabled: false);

    expect(calls, ['disable']);
    events.add('up');
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['disable']);
    controller.dispose();
  });

  test('启用时拦截并只订阅一次', () async {
    final controller = buildController();

    controller.sync(enabled: true);
    controller.sync(enabled: true);

    expect(calls, ['enable', 'enable']);
    events.add('up');
    await Future<void>.delayed(Duration.zero);
    expect(calls, ['enable', 'enable', 'previous']);
    controller.dispose();
  });

  test('音量下键翻下一页', () async {
    final controller = buildController();
    controller.sync(enabled: true);

    events.add('down');
    await Future<void>.delayed(Duration.zero);

    expect(calls, contains('next'));
    controller.dispose();
  });

  test('禁用期间到达的事件不翻页', () async {
    final controller = buildController();
    controller.sync(enabled: true);
    enabled = false;

    events.add('up');
    await Future<void>.delayed(Duration.zero);

    expect(calls, isNot(contains('previous')));
    controller.dispose();
  });

  test('dispose 取消订阅并放开拦截', () async {
    final controller = buildController();
    controller.sync(enabled: true);
    calls.clear();

    controller.dispose();
    events.add('up');
    await Future<void>.delayed(Duration.zero);

    expect(calls, ['disable']);
  });
}
