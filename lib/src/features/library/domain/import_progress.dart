/// 导入/恢复进度事件与结果的值对象。
///
/// 这些类型同时被 data（服务发事件）、application（编排）与 presentation（对话框渲染）
/// 消费，因此落在 domain：任一层都可以依赖 domain，避免 data → application 的逆向依赖。
library;

// ---------------------------------------------------------------------------
// 进度事件基类
// ---------------------------------------------------------------------------

enum ProgressLogType { info, warning, error, success }

class ProgressLog {
  final String message;
  final ProgressLogType type;

  ProgressLog(this.message, this.type);
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

/// Result of a library import operation.
sealed class ImportResult {
  const ImportResult();
}

/// Import completed successfully. [importedBooks] is the count of books processed.
final class ImportSuccess extends ImportResult {
  final int importedBooks;
  const ImportSuccess({required this.importedBooks});
}

/// Import failed with [message].
final class ImportFailure extends ImportResult {
  final String message;
  const ImportFailure(this.message);
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

String _importResultToMessage(ImportResult? result, String currentFileName) {
  if (result == null) {
    return 'Import "$currentFileName" in progress...';
  } else if (result is ImportSuccess) {
    return 'Import "$currentFileName" completed successfully.';
  } else if (result is ImportFailure) {
    return 'Import "$currentFileName" failed: ${result.message}.';
  } else {
    return 'Unknown import result.';
  }
}

ProgressLogType _importResultToLogType(ImportResult? result) {
  if (result == null) {
    return ProgressLogType.info;
  } else if (result is ImportSuccess) {
    return ProgressLogType.success;
  } else if (result is ImportFailure) {
    return ProgressLogType.error;
  } else {
    return ProgressLogType.info;
  }
}

/// Snapshot of the restore progress emitted by 导入服务.
class BackupImportProgress extends ProgressLog {
  BackupImportProgress({
    required this.current,
    required this.total,
    required this.currentFileName,
    this.result,
  }) : super(
         _importResultToMessage(result, currentFileName),
         _importResultToLogType(result),
       );

  /// Number of books fully processed so far.
  final int current;

  /// Total number of books to restore.
  final int total;

  /// Title (or hash) of the book currently being processed.
  final String currentFileName;

  /// 单本保存成功或恢复中止时携带结果；流结束代表本次恢复结束。
  final ImportResult? result;
}
