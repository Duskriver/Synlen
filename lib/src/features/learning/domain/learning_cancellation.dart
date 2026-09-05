/// 一次学习查询的取消信号；取消后新注册的操作也立即取消。
class LearningCancellation {
  final _callbacks = <void Function()>{};
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  /// 返回注销函数，操作结束后应注销，避免保留已完成请求。
  void Function() onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
      return () {};
    }
    _callbacks.add(callback);
    return () => _callbacks.remove(callback);
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    final callbacks = _callbacks.toList();
    _callbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void throwIfCancelled() {
    if (_isCancelled) throw const LearningCancelled();
  }
}

/// 已关闭或被替代的查询，不作为用户可见错误展示。
class LearningCancelled implements Exception {
  const LearningCancelled();
}
