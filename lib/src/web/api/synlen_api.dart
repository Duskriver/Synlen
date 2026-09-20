import 'dart:convert';

import 'webview_bridge.dart';

/// Dart 侧渲染命令：Future 完成表示对应 JavaScript 操作已完成。
class SynlenApi {
  final WebViewBridge _bridge;

  SynlenApi(this._bridge);

  Future<void> loadFrame(
    String slot,
    String url,
    String anchors,
    String properties,
  ) => _bridge.callAndWait(
    (t) =>
        'window.api.loadFrame($t, ${jsonEncode(slot)}, ${jsonEncode(url)}, $anchors, $properties)',
  );

  Future<void> jumpToPageFor(String slot, int pageIndex) => _bridge.callAndWait(
    (t) => "window.api.jumpToPageFor($t, '$slot', $pageIndex)",
  );

  Future<void> jumpToLastPageOfFrame(String slot) => _bridge.callAndWait(
    (t) => "window.api.jumpToLastPageOfFrame($t, '$slot')",
  );

  Future<void> cycleFrames(String direction) =>
      _bridge.callAndWait((t) => "window.api.cycleFrames($t, '$direction')");

  Future<void> jumpToPage(int pageIndex) =>
      _bridge.callAndWait((t) => 'window.api.jumpToPage($t, $pageIndex)', 1000);

  Future<void> restoreScrollPosition(double ratio) => _bridge.callAndWait(
    (t) => 'window.api.restoreScrollPosition($t, $ratio)',
    1000,
  );

  Future<void> waitForRender() =>
      _bridge.callAndWait((t) => 'window.api.waitForRender($t)', 1000);

  Future<void> updateTheme(
    double viewWidth,
    double viewHeight,
    Map<String, dynamic> theme,
  ) {
    final themeJson = jsonEncode(theme);
    return _bridge.callAndWait(
      (t) => 'window.api.updateTheme($t, $viewWidth, $viewHeight, $themeJson)',
    );
  }

  Future<void> checkLongPressElementAt(double x, double y) =>
      _bridge.evaluate('window.api.checkLongPressElementAt($x, $y)');

  Future<void> checkTapElementAt(double x, double y) =>
      _bridge.evaluate('window.api.checkTapElementAt($x, $y)');
}
