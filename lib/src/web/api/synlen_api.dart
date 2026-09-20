import 'dart:convert';

import 'webview_bridge.dart';

/// Dart 侧渲染命令：Future 完成表示对应 JavaScript 操作已完成。
class SynlenApi {
  final WebViewBridge _bridge;
  int _nextWordRequest = 0;
  int? _pendingWordRequest;

  SynlenApi(this._bridge);

  Future<void> loadFrame(
    String slot,
    String url,
    String anchors,
    String properties,
  ) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) =>
          'window.api.loadFrame($t, ${jsonEncode(slot)}, ${jsonEncode(url)}, $anchors, $properties)',
    );
  }

  Future<void> jumpToPageFor(String slot, int pageIndex) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) => "window.api.jumpToPageFor($t, '$slot', $pageIndex)",
    );
  }

  Future<void> jumpToLastPageOfFrame(String slot) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) => "window.api.jumpToLastPageOfFrame($t, '$slot')",
    );
  }

  Future<void> cycleFrames(String direction) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) => "window.api.cycleFrames($t, '$direction')",
    );
  }

  Future<void> jumpToPage(int pageIndex) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) => 'window.api.jumpToPage($t, $pageIndex)',
      1000,
    );
  }

  Future<void> restoreScrollPosition(double ratio) {
    invalidateWordRequest();
    return _bridge.callAndWait(
      (t) => 'window.api.restoreScrollPosition($t, $ratio)',
      1000,
    );
  }

  Future<void> waitForRender() =>
      _bridge.callAndWait((t) => 'window.api.waitForRender($t)', 1000);

  Future<void> updateTheme(
    double viewWidth,
    double viewHeight,
    Map<String, dynamic> theme,
  ) {
    invalidateWordRequest();
    final themeJson = jsonEncode(theme);
    return _bridge.callAndWait(
      (t) => 'window.api.updateTheme($t, $viewWidth, $viewHeight, $themeJson)',
    );
  }

  Future<void> checkLongPressElementAt(double x, double y) {
    invalidateWordRequest();
    return _bridge.evaluate('window.api.checkLongPressElementAt($x, $y)');
  }

  Future<void> checkTapElementAt(double x, double y) {
    final request = ++_nextWordRequest;
    _pendingWordRequest = request;
    return _bridge.evaluate('window.api.checkTapElementAt($x, $y, $request)');
  }

  /// 每次点词只接收一次回执；新点击与排版导航使旧坐标失效。
  bool acceptWordRequest(int requestId) {
    if (_pendingWordRequest != requestId) return false;
    _pendingWordRequest = null;
    return true;
  }

  void invalidateWordRequest() => _pendingWordRequest = null;
}
