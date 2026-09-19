import 'dart:async';

/// 管理一次 WebView 挂载期间的命令回执；超时、执行失败、卸载均使命令失败。
class WebViewBridge {
  Future<void> Function(String source)? _evaluate;
  Object? _viewId;
  int _currentToken = 0;
  final Map<int, Completer<void>> _pending = {};

  /// 同一原生视口切换控制器时保留在途回执；换视口或未提供标识则取消旧请求。
  void attach(Future<void> Function(String source) evaluate, {Object? viewId}) {
    if (_evaluate != null && (viewId == null || viewId != _viewId)) detach();
    _evaluate = evaluate;
    _viewId = viewId;
  }

  void detach() {
    _evaluate = null;
    _viewId = null;
    for (final completion in _pending.values) {
      completion.completeError(StateError('阅读视口已关闭'));
    }
    _pending.clear();
  }

  Future<void> evaluate(String source) {
    final evaluate = _evaluate;
    if (evaluate == null) return Future.error(StateError('阅读视口尚未就绪'));
    return evaluate(source);
  }

  /// 未知回执（含超时或上一次挂载的迟到回执）不影响当前命令。
  void resolveToken(int token) {
    _pending.remove(token)?.complete();
  }

  Future<void> callAndWait(
    String Function(int token) source, [
    int timeoutMs = 10000,
  ]) {
    final evaluate = _evaluate;
    if (evaluate == null) return Future.error(StateError('阅读视口尚未就绪'));
    final token = ++_currentToken;
    final completion = Completer<void>();
    _pending[token] = completion;
    // 先订阅回执再执行脚本，执行器内同步回执或卸载也不会丢失结果。
    return Future.wait<void>([
          completion.future,
          Future.sync(() => evaluate(source(token))),
        ], eagerError: true)
        .timeout(Duration(milliseconds: timeoutMs))
        .then<void>((_) {})
        .whenComplete(() {
          _pending.remove(token);
        });
  }
}
