import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/features/library/application/progress_log.dart';
import 'package:synlen/src/features/library/data/services/import_backup_service_provider.dart';
import 'package:synlen/src/features/library/data/services/unified_import_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/database/app_database.dart';
import '../data/services/epub_import_service_provider.dart';

part 'library_notifier.g.dart';

enum ImportStatus { processing, success, failed }

class ImportProgress extends ProgressLog {
  final int totalCount;
  final int currentCount;
  final String currentFileName;
  final ImportStatus status;
  final String? errorMessage;
  final ShelfBook? book;

  ImportProgress({
    required this.totalCount,
    required this.currentCount,
    required this.currentFileName,
    required this.status,
    this.errorMessage,
    this.book,
  }) : super(
         status == ImportStatus.failed
             ? errorMessage ?? 'Unknown error'
             : (status == ImportStatus.success
                   ? 'Imported: ${book?.title}'
                   : 'Processing: $currentFileName'),
         status == ImportStatus.failed
             ? ProgressLogType.error
             : (status == ImportStatus.success
                   ? ProgressLogType.success
                   : ProgressLogType.info),
       );
}

/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。
///
/// 必须 keepAlive：`importPipelineStream` / `importLibraryFromFolder` 是
/// async* 函数，方法体推迟到 UI 对话框监听流之后才执行；若为 autoDispose，
/// 调用方只做 `read`（无监听），provider 会在流开始运行前被销毁，方法体内的
/// `ref.read` 随之抛出 "Cannot use the Ref ... after it has been disposed"。
@Riverpod(keepAlive: true)
class LibraryNotifier extends _$LibraryNotifier {
  @override
  void build() {}

  Stream<ProgressLog> importLibraryFromFolder(BackupPaths backupPaths) async* {
    yield ProgressLog(
      'Starting import from folder: ${backupPaths.rootPath}',
      ProgressLogType.info,
    );

    final importService = ref.read(importBackupServiceProvider);

    try {
      await for (final progress in importService.importLibraryFromFolder(
        backupPaths,
      )) {
        yield progress;
      }
    } catch (e) {
      yield ProgressLog(
        'Failed to import from folder: $e',
        ProgressLogType.error,
      );
      appLogger.e('Import from folder error: $e');
    }

    yield ProgressLog(
      'Import from folder completed. Refreshing library...',
      ProgressLogType.success,
    );
  }

  /// Stream pipeline to process files one by one: Cache -> Import -> Clean.
  /// This prevents OOM and storage issues when importing massive folders.
  Stream<ProgressLog> importPipelineStream(List<PlatformPath> paths) async* {
    yield ProgressLog(
      'Starting import of ${paths.length} books',
      ProgressLogType.info,
    );
    final totalCount = paths.length;
    if (totalCount == 0) return;

    final unifiedImportService = ref.read(unifiedImportServiceProvider);
    final epubImportService = ref.read(epubImportServiceProvider);

    int currentCount = 0;

    for (final path in paths) {
      ImportableEpub? importable;
      String currentFileName = '';

      try {
        currentFileName = path.name;

        // 1. Notify UI that caching is done and actual import is starting
        yield ImportProgress(
          totalCount: totalCount,
          currentCount: currentCount,
          currentFileName: currentFileName,
          status: ImportStatus.processing,
        );

        // 2. Cache the file from URI to local temp directory
        importable = await unifiedImportService.processEpub(path);

        yield ProgressLog(
          'Processing file $currentFileName ($currentCount of $totalCount)',
          ProgressLogType.info,
        );

        // 3. Import the book and wait for the Either result
        final result = await epubImportService.importBook(
          importable.cacheFile,
          precomputedHash: importable.hash,
          originalFileName: importable.originalName,
          moveSourceFile: true,
        );

        // 4. Notify UI of success or failure for this file
        yield result.fold(
          (errorMessage) => ImportProgress(
            totalCount: totalCount,
            currentCount: currentCount,
            currentFileName: currentFileName,
            status: ImportStatus.failed,
            errorMessage: errorMessage,
          ),
          (book) => ImportProgress(
            totalCount: totalCount,
            currentCount: currentCount,
            currentFileName: currentFileName,
            status: ImportStatus.success,
            book: book,
          ),
        );
      } catch (e) {
        // Handle unexpected errors during the caching or stream reading phase
        yield ImportProgress(
          totalCount: totalCount,
          currentCount: currentCount,
          currentFileName: currentFileName,
          status: ImportStatus.failed,
          errorMessage: 'Pipeline error: $e',
        );
      } finally {
        // 5. CRITICAL: Always clean up the temporary cache file IMMEDIATELY
        if (importable != null) {
          try {
            await unifiedImportService.cleanCache(importable.cacheFile);
          } catch (cleanError) {
            appLogger.w('Failed to clean cache file: $cleanError');
          }
        }
        currentCount++;
      }
    }

    // 6. After all files are processed, refresh the book list to update UI
    yield ProgressLog(
      'Import completed. Refreshing library...',
      ProgressLogType.success,
    );
  }
}
