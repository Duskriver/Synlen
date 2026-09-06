import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/library/application/library_notifier.dart';
import 'package:synlen/src/features/library/application/progress_log.dart';
import 'package:synlen/src/features/library/data/services/import_backup_service.dart';
import 'package:synlen/src/features/library/presentation/widgets/progress_dialog.dart';

/// Hosts the restore-backup progress dialog.
/// Identical architecture to [_ImportProgressDialog] but interprets
/// [BackupImportProgress] events instead of [ImportProgress].
class RestoreProgressDialog extends StatefulWidget {
  final Stream<ProgressLog> stream;
  final AppLocalizations l10n;

  const RestoreProgressDialog({
    super.key,
    required this.stream,
    required this.l10n,
  });

  @override
  State<RestoreProgressDialog> createState() => _RestoreProgressDialogState();
}

class _RestoreProgressDialogState extends State<RestoreProgressDialog> {
  StreamSubscription<ProgressLog>? _sub;

  int _totalCount = 0;
  int _currentCount = 0;
  int _successCount = 0;
  int _failedCount = 0;
  String _currentFileName = '';
  bool _isCompleted = false;
  bool _hasFailed = false;
  final List<ProgressLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _sub = widget.stream.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
  }

  void _onData(ProgressLog log) {
    if (!mounted) return;
    setState(() {
      _logs.add(log);
      if (log is BackupImportProgress) {
        _totalCount = log.total;
        _currentCount = log.current;
        _currentFileName = log.currentFileName;
        if (log.result is ImportSuccess) {
          _successCount++;
        } else if (log.result is ImportFailure) {
          _hasFailed = true;
          if (_currentCount < _totalCount) _failedCount++;
        }
      }
    });
  }

  void _onError(Object error, StackTrace st) {
    if (!mounted) return;
    appLogger.e('恢复流失败', error: error, stackTrace: st);
    setState(() {
      _hasFailed = true;
      _isCompleted = true;
    });
  }

  void _onDone() {
    if (!mounted) return;
    setState(() => _isCompleted = true);
    if (_hasFailed) {
      ToastService.showError(widget.l10n.restoreIncomplete);
    } else {
      ToastService.showSuccess(widget.l10n.restoreCompleted);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasProgress = _totalCount > 0;
    final isDone = _isCompleted;
    final progressValue = hasProgress
        ? _currentCount / _totalCount
        : (isDone ? 0.0 : null);

    return ProgressDialog(
      title: widget.l10n.restoring,
      completeTitle: _hasFailed
          ? widget.l10n.restoreIncomplete
          : widget.l10n.restoreCompleted,
      completedMessage: _hasFailed ? '' : null,
      progressMessage: widget.l10n.restoringProgress(
        _successCount,
        _failedCount,
        _totalCount - _successCount - _failedCount,
      ),
      processingMessage: widget.l10n.progressing(_currentFileName),
      progressValue: progressValue,
      isCompleted: isDone,
      logs: _logs,
    );
  }
}
