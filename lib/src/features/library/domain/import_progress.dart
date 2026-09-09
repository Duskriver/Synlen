/// 导入/恢复进度事件与结果的值对象。
///
/// 这些类型同时被 data（服务发事件）、application（编排）与 presentation（对话框渲染）
/// 消费，因此落在 domain：任一层都可以依赖 domain，避免 data → application 的逆向依赖。
library;

import 'library_exception.dart';

// ---------------------------------------------------------------------------
// 进度事件基类
// ---------------------------------------------------------------------------

enum ProgressLogType { info, warning, error, success }

class ProgressLog {
  final String message;
  final ProgressLogType type;

  /// 失败事件携带的类型化错误；presentation 按 `error.code` 映射 l10n 文案，
  /// [message] 只是内部日志文本，不做内容匹配。
  final LibraryException? error;

  ProgressLog(this.message, this.type, {this.error});
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

/// Import failed with a typed [error]；用户文案由 presentation 按错误码映射。
final class ImportFailure extends ImportResult {
  final LibraryException error;
  const ImportFailure(this.error);
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
    return 'Import "$currentFileName" failed: ${result.error}.';
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
         error: switch (result) {
           ImportFailure(:final error) => error,
           _ => null,
         },
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
