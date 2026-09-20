import 'dart:async';

/// 旋转后的延迟落页属于当前视口；拆除或新一次旋转使旧校正失效。
class ReaderOrientationAlignment {
  ReaderOrientationAlignment({required this.onError});

  final void Function(Object, StackTrace) onError;
  Timer? _timer;
  int _revision = 0;
  bool _disposed = false;

  void schedule(Future<void> Function() align) {
    if (_disposed) return;
    _timer?.cancel();
    final revision = ++_revision;
    _timer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await align();
      } catch (error, stack) {
        if (!_disposed && revision == _revision) onError(error, stack);
      }
    });
  }

  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _timer = null;
  }
}
