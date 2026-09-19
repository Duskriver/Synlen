import '../../../core/database/app_database.dart';
import '../../../core/services/app_logger.dart';
import '../data/library_book_store.dart';

enum BookDeletionResult { deleted, cleanupPending, failed }

/// 逻辑删除提交后清理文件；清理失败保留墓碑，由存储清理重试。
class BookDeletion {
  BookDeletion({
    required LibraryBookStore store,
    required Future<void> Function(ShelfBook) removeFiles,
  }) : _store = store,
       _removeFiles = removeFiles;

  final LibraryBookStore _store;
  final Future<void> Function(ShelfBook) _removeFiles;

  Future<BookDeletionResult> delete(ShelfBook book) async {
    try {
      await _store.deleteBookWithManifest(book);
    } catch (error, stack) {
      appLogger.e('删除书目事务失败', error: error, stackTrace: stack);
      return BookDeletionResult.failed;
    }
    try {
      await _removeFiles(book);
      return BookDeletionResult.deleted;
    } catch (error, stack) {
      appLogger.e('书目已删除，物理文件等待清理', error: error, stackTrace: stack);
      return BookDeletionResult.cleanupPending;
    }
  }
}
