import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_readium/reader_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('文字回执只到所属视口，拒绝超限与非字符串载荷', () async {
    final firstEvents = <String>[];
    final secondEvents = <String>[];
    final first = ReadiumReaderChannel(
      'test/reader/first',
      onReaderReady: () {},
      onPageChanged: (_) {},
      onTextInteraction: firstEvents.add,
    );
    final second = ReadiumReaderChannel(
      'test/reader/second',
      onReaderReady: () {},
      onPageChanged: (_) {},
      onTextInteraction: secondEvents.add,
    );
    await first.onMethodCall(const MethodCall('onTextInteraction', '{"sessionId":"first"}'));
    await second.onMethodCall(const MethodCall('onTextInteraction', '{"sessionId":"second"}'));
    await first.onMethodCall(MethodCall('onTextInteraction', 'x' * 65537));
    await first.onMethodCall(const MethodCall('onTextInteraction', {'kind': 'word'}));
    expect(firstEvents, ['{"sessionId":"first"}']);
    expect(secondEvents, ['{"sessionId":"second"}']);
    first.setMethodCallHandler(null);
    second.setMethodCallHandler(null);
  });

  test('目录与恢复导航原样传递锚点、CFI、扩展位置和媒体类型', () async {
    const name = 'test/reader/navigation';
    final sent = <List<dynamic>>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // ignore: cascade_invocations
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      expect(call.method, 'go');
      sent.add(call.arguments as List<dynamic>);
      return null;
    });
    final channel = ReadiumReaderChannel(name, onReaderReady: () {}, onPageChanged: (_) {});
    final originals = <Map<String, dynamic>>[
      {
        'href': 'OEBPS/chapter2.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {'progression': 0.0},
      },
      {
        'href': 'OEBPS/chapter2.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {
          'fragments': ['top'],
        },
      },
      {
        'href': 'OEBPS/chapter2.xhtml',
        'type': 'application/xhtml+xml',
        'locations': {
          'fragments': ['epubcfi(/6/4!/4/2)'],
          'cssSelector': '#p42',
          'progression': 0.45,
          'customLocation': 'keep',
        },
        'text': {'highlight': 'Reader position'},
      },
    ];
    for (final original in originals) {
      final locator = Locator.fromJsonString(jsonEncode(original))!;
      await channel.go(locator, isAudioBookWithText: false, animated: true);
      expect(jsonDecode(sent.last[0] as String), locator.toJson());
      expect(sent.last.sublist(1), [true, false]);
    }
    expect(sent, hasLength(originals.length));
    channel.setMethodCallHandler(null);
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
  });

  test('关闭 Future 等待原生拆除回包', () async {
    const name = 'test/reader/dispose';
    final completed = Completer<void>();
    final invoked = Completer<void>();
    // 同一 messenger 在测试结束后还需卸载处理器。
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // ignore: cascade_invocations
    messenger.setMockMethodCallHandler(const MethodChannel(name), (call) async {
      expect(call.method, 'dispose');
      invoked.complete();
      await completed.future;
      return null;
    });
    final lateEvents = <String>[];
    final channel = ReadiumReaderChannel(
      name,
      onReaderReady: () => lateEvents.add('ready'),
      onPageChanged: (_) => lateEvents.add('location'),
      onExternalLinkActivated: lateEvents.add,
      onTextInteraction: lateEvents.add,
    );
    var disposed = false;
    final future = channel.dispose().then((_) => disposed = true);
    await invoked.future;
    expect(disposed, isFalse);
    await channel.onMethodCall(const MethodCall('onReaderReady'));
    await channel.onMethodCall(const MethodCall('onExternalLinkActivated', 'https://example.com'));
    await channel.onMethodCall(const MethodCall('onTextInteraction', '{}'));
    expect(lateEvents, isEmpty);
    completed.complete();
    await future;
    expect(disposed, isTrue);
    messenger.setMockMethodCallHandler(const MethodChannel(name), null);
  });
}
