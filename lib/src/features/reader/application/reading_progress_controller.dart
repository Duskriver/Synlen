import 'dart:async';

import '../../../core/services/app_logger.dart';
import '../domain/reading_progress.dart';

/// 合并连续翻页，串行提交完整位置；关闭时提交尚未落库的进度。
class ReadingProgressController {
  ReadingProgressController({
    required Future<void> Function(ReadingProgress) save,
    required void Function() onSaveFailed,
    Duration debounce = const Duration(seconds: 1),
  }) : _save = save,
       _onSaveFailed = onSaveFailed,
       _debounce = debounce;

  final Future<void> Function(ReadingProgress) _save;
  final void Function() _onSaveFailed;
  final Duration _debounce;
  Timer? _timer;
  ReadingProgress? _pending;
  ReadingProgress? _saved;
  Future<bool>? _saving;
  bool _closed = false;
  bool _failed = false;

  /// 加载或重新分页期间不采集位置，保留上一份有效进度。
  void record(ReadingProgress progress, {required bool isReady}) {
    if (_closed ||
        !isReady ||
        progress.chapterIndex < 0 ||
        progress.pageCount <= 0 ||
        progress.pageIndex < 0 ||
        progress.pageIndex >= progress.pageCount) {
      return;
    }
    if (_pending == progress ||
        (_saving == null && _pending == null && _saved == progress)) {
      return;
    }
    _pending = progress;
    _timer?.cancel();
    _timer = Timer(_debounce, flush);
  }

  /// 等待全部已记录位置写入；失败保留最新位置，下一次调用可重试。
  Future<bool> flush() {
    _timer?.cancel();
    _timer = null;
    if (_saving != null) return _saving!;
    if (_pending == null) return Future.value(true);

    final completion = Completer<bool>();
    _saving = completion.future;
    unawaited(_drain(completion));
    return completion.future;
  }

  Future<void> _drain(Completer<bool> completion) async {
    var succeeded = true;
    while (_pending != null) {
      final progress = _pending!;
      _pending = null;
      if (progress == _saved) continue;
      try {
        await _save(progress);
        _saved = progress;
        _failed = false;
      } catch (error, stackTrace) {
        _pending ??= progress;
        appLogger.e('阅读进度保存失败', error: error, stackTrace: stackTrace);
        if (!_failed) _onSaveFailed();
        _failed = true;
        succeeded = false;
        break;
      }
    }
    _saving = null;
    completion.complete(succeeded);
  }

  /// 停止采集；在途写入继续完成，调用者可等待最终结果。
  Future<bool> close() {
    _closed = true;
    return flush();
  }
}
