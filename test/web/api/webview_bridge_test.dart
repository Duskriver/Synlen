import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/web/api/webview_bridge.dart';

void main() {
  test('同一原生视口从预加载转为可见时保留在途请求并更新执行器', () async {
    final bridge = WebViewBridge();
    var token = 0;
    bridge.attach(
      (source) async => token = int.parse(source),
      viewId: 'headless-view',
    );
    final pending = bridge.callAndWait((t) => '$t');
    final completion = expectLater(pending, completes);
    var visibleCalled = false;
    bridge.attach((source) async {
      visibleCalled = true;
      bridge.resolveToken(int.parse(source));
    }, viewId: 'headless-view');
    bridge.resolveToken(token);
    await completion;
    await bridge.callAndWait((t) => '$t');
    expect(visibleCalled, isTrue);
    bridge.detach();
  });

  test('同步回执也能完成，多个命令可乱序完成', () async {
    final bridge = WebViewBridge();
    bridge.attach((source) async => bridge.resolveToken(int.parse(source)));
    await bridge.callAndWait((token) => '$token');
    final tokens = <int>[];
    bridge.attach((source) async => tokens.add(int.parse(source)));
    var firstDone = false;
    final first = bridge
        .callAndWait((token) => '$token')
        .then((_) => firstDone = true);
    final second = bridge.callAndWait((token) => '$token');
    bridge.resolveToken(tokens.last);
    await second;
    expect(firstDone, isFalse);
    bridge.resolveToken(tokens.first);
    await first;
  });

  test('真正更换视口时取消旧请求，旧回执不能完成新请求', () async {
    final bridge = WebViewBridge();
    var token = 0;
    Future<void> execute(String source) async => token = int.parse(source);
    bridge.attach(execute, viewId: 'first');
    final old = bridge.callAndWait((t) => '$t');
    final oldToken = token;
    final canceled = expectLater(old, throwsStateError);
    bridge.attach(execute, viewId: 'second');
    await canceled;
    var completed = false;
    final current = bridge
        .callAndWait((t) => '$t')
        .then((_) => completed = true);
    bridge.resolveToken(oldToken);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    bridge.resolveToken(token);
    await current;
    bridge.detach();
  });

  test('无视口、执行失败、超时均失败；迟到回执不完成下一次命令', () async {
    final bridge = WebViewBridge();
    await expectLater(bridge.callAndWait((t) => '$t'), throwsStateError);
    bridge.attach((_) async => throw StateError('脚本失败'));
    await expectLater(bridge.callAndWait((t) => '$t'), throwsStateError);
    final tokens = <int>[];
    bridge.attach((source) async => tokens.add(int.parse(source)));
    await expectLater(
      bridge.callAndWait((t) => '$t', 1),
      throwsA(isA<TimeoutException>()),
    );
    var completed = false;
    final pending = bridge
        .callAndWait((t) => '$t')
        .then((_) => completed = true);
    bridge.resolveToken(tokens.first);
    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);
    bridge.resolveToken(tokens.last);
    await pending;
  });

  test('执行器内卸载使在途命令失败，重新挂载不复用旧 token', () async {
    final bridge = WebViewBridge();
    bridge.attach((_) async => bridge.detach());
    await expectLater(bridge.callAndWait((t) => '$t'), throwsStateError);
    bridge.attach((source) async => bridge.resolveToken(int.parse(source)));
    await bridge.callAndWait((t) => '$t');
    bridge.detach();
  });
}
