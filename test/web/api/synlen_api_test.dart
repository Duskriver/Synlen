import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/web/api/synlen_api.dart';
import 'package:synlen/src/web/api/webview_bridge.dart';

void main() {
  late WebViewBridge bridge;
  late SynlenApi api;
  late List<String> scripts;
  setUp(() {
    scripts = [];
    bridge = WebViewBridge()..attach((source) async => scripts.add(source));
    api = SynlenApi(bridge);
  });
  tearDown(() => bridge.detach());

  int lastWordRequest() =>
      int.parse(RegExp(r', (\d+)\)$').firstMatch(scripts.last)!.group(1)!);

  test('后一次点词替换前一次请求，每个回执只接收一次', () async {
    await api.checkTapElementAt(12, 24);
    final first = lastWordRequest();
    await api.checkTapElementAt(13, 25);
    final second = lastWordRequest();
    expect(second, greaterThan(first));
    expect(api.acceptWordRequest(first), isFalse);
    expect(api.acceptWordRequest(second), isTrue);
    expect(api.acceptWordRequest(second), isFalse);
  });

  for (final action in <String, Future<void> Function(SynlenApi)>{
    '翻页': (api) => api.jumpToPage(2),
    '切换章节': (api) => api.cycleFrames('next'),
    '章节重新定位': (api) => api.jumpToPageFor('curr', 2),
    '章节末页': (api) => api.jumpToLastPageOfFrame('curr'),
    '恢复位置': (api) => api.restoreScrollPosition(0.5),
    '加载章节': (api) =>
        api.loadFrame('curr', 'book://localhost/chapter', '[]', '[]'),
    '重新排版': (api) => api.updateTheme(320, 600, {}),
  }.entries) {
    test('${action.key}开始后拒绝旧词回执，完成后新点击仍可打开', () async {
      await api.checkTapElementAt(12, 24);
      final oldRequest = lastWordRequest();
      final pendingNavigation = action.value(api);
      expect(api.acceptWordRequest(oldRequest), isFalse);
      final token = int.parse(
        RegExp(r'\((\d+)').firstMatch(scripts.last)!.group(1)!,
      );
      bridge.resolveToken(token);
      await pendingNavigation;
      await api.checkTapElementAt(20, 30);
      final newRequest = lastWordRequest();
      expect(api.acceptWordRequest(oldRequest), isFalse);
      expect(api.acceptWordRequest(newRequest), isTrue);
    });
  }

  test('长按句子或视口失效后不会打开旧词卡', () async {
    await api.checkTapElementAt(12, 24);
    final beforeLongPress = lastWordRequest();
    await api.checkLongPressElementAt(12, 24);
    expect(scripts.last, 'window.api.checkLongPressElementAt(12.0, 24.0)');
    expect(api.acceptWordRequest(beforeLongPress), isFalse);
    await api.checkTapElementAt(12, 24);
    final beforeResize = lastWordRequest();
    api.invalidateWordRequest();
    expect(api.acceptWordRequest(beforeResize), isFalse);
  });
}
