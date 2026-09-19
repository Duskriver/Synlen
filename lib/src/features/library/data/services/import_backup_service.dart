import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import '../library_book_store.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';

import '../../domain/book_format.dart';
import '../../domain/import_progress.dart';
import '../../domain/library_exception.dart';
import 'backup_decoders.dart';
import 'backup_json_mapper.dart';
import 'book_file_changes.dart';

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Zero-memory overhead library restore service.
///
/// Mirrors the folder structure produced by [ExportBackupService]:
/// ```
/// synlen-backup-{timestamp}/
///   ├── books/         ← .epub files (one per book)
///   ├── covers/        ← cover images
///   ├── manifests/     ← {hash}.json (serialised BookManifest)
///   └── shelf.json     ← ShelfBook list + ShelfGroup list
/// ```
///
/// Memory profile:
///   Physical files (.epub, covers) are restored with [File.copy] — a
///   kernel-level operation that never loads file bytes into the Dart heap.
///   Only the JSON payloads (shelf.json + individual manifest files) are
///   materialised in memory, and those are small by design.
class ImportBackupService {
  final ShelfBookRepository _shelfBookRepository;
  final UnifiedImportService _importService;
  final LibraryBookStore _bookStore;

  ImportBackupService({
    required ShelfBookRepository shelfBookRepository,
    required LibraryBookStore bookStore,
    required UnifiedImportService importService,
  }) : _shelfBookRepository = shelfBookRepository,
       _importService = importService,
       _bookStore = bookStore;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Restores a library from [backupPaths], emitting [BackupImportProgress]
  /// events in real time so the UI can display a progress indicator.
  ///
  /// 单本的全部数据库写入成功后才计数；失败事件保留此前成功数并中止恢复。
  Stream<ProgressLog> importLibraryFromFolder(BackupPaths backupPaths) async* {
    var importedCount = 0;
    var totalCount = 0;
    var currentFileName = '';

    // 失败不会清零已成功恢复的书籍数。
    BackupImportProgress failure(LibraryException error) =>
        BackupImportProgress(
          current: importedCount,
          total: totalCount,
          currentFileName: currentFileName,
          result: ImportFailure(error),
        );

    try {
      // -----------------------------------------------------------------------
      // 1. Read and parse global shelf.json via UnifiedImportService
      // -----------------------------------------------------------------------
      yield ProgressLog('Reading backup metadata...', ProgressLogType.info);
      final shelfString = await _importService.processPlainFile(
        backupPaths.shelfFile,
      );
      final shelfJson = jsonDecode(shelfString) as Map<String, dynamic>;

      // 版本分派：version 高于支持上限时在此抛出，恢复尚未写库即中止。
      final shelfData = decodeShelfBackup(shelfJson);
      final groupsJson = shelfData.groups;
      final booksJson = shelfData.books;
      totalCount = booksJson.length;

      // Emit the initial state so the UI can show indeterminate progress
      // while groups & directories are being set up.
      yield ProgressLog(
        'Preparing to restore ${booksJson.length} books...',
        ProgressLogType.info,
      );

      // -----------------------------------------------------------------------
      // 2. Restore groups (upsert by name to avoid duplicates).
      // -----------------------------------------------------------------------
      yield ProgressLog('Restoring shelf groups...', ProgressLogType.info);

      if (groupsJson.isNotEmpty) {
        final groups = groupsJson.map(mapToShelfGroup).toList();
        await _bookStore.restoreGroups(groups);
      }

      yield ProgressLog('Groups restored.', ProgressLogType.info);

      // -----------------------------------------------------------------------
      // 3. Ensure internal storage directories exist.
      // -----------------------------------------------------------------------
      final internalBooksDir = await Directory(
        p.join(AppStorage.documentsPath, AppStorageConstants.booksDir),
      ).create(recursive: true);

      final internalCoversDir = await Directory(
        p.join(AppStorage.documentsPath, AppStorageConstants.coversDir),
      ).create(recursive: true);

      // -----------------------------------------------------------------------
      // 4. Restore books one-by-one, yielding progress; upsert each immediately.
      // -----------------------------------------------------------------------
      yield ProgressLog('Restoring books...', ProgressLogType.info);

      for (final bookMap in booksJson) {
        final hash = bookMap['fileHash'] as String;
        final title = (bookMap['title'] as String?)?.trim();
        final displayName = (title != null && title.isNotEmpty) ? title : hash;
        currentFileName = displayName;
        // 旧版备份无 format 字段，按 EPUB 处理
        final format =
            BookFormat.values.asNameMap()[bookMap['format']] ?? BookFormat.epub;
        final bookFileName = '$hash${format.fileExtension}';

        // Yield “processing this book” before doing any heavy I/O.
        yield BackupImportProgress(
          current: importedCount,
          total: booksJson.length,
          currentFileName: displayName,
        );

        final pathsForBook = backupPaths.bookPaths[hash];
        if (pathsForBook == null) {
          throw LibraryException(
            LibraryErrorCode.backupCorrupted,
            '备份缺少书籍或清单：$hash',
          );
        }

        final files = BookFileChanges();
        try {
          // -- A. Process & Copy book file --
          final destBook = File(p.join(internalBooksDir.path, bookFileName));
          if (!destBook.existsSync()) {
            final importableBook = await _importService.processEpub(
              pathsForBook.epubPath,
            );
            try {
              await files.copyIfMissing(importableBook.cacheFile, destBook);
            } finally {
              await _importService.cleanCache(importableBook.cacheFile);
            }
          }

          // -- B. Process & Copy Cover --
          final existingBook = await _shelfBookRepository.getBookByHash(hash);
          final existingCover = existingBook?.coverPath;
          final keepLocalCover =
              existingBook != null &&
              existingBook.updatedAt >= (bookMap['updatedAt'] as int) &&
              existingCover != null &&
              await File(
                p.join(AppStorage.documentsPath, existingCover),
              ).exists();
          String? restoredCoverPath = keepLocalCover ? existingCover : null;
          if (!keepLocalCover && pathsForBook.coverPath != null) {
            try {
              final coverBytes = await _importService.processBinaryFile(
                pathsForBook.coverPath!,
              );
              final coverFileName = pathsForBook.coverPath!.name;
              final destCover = File(
                p.join(internalCoversDir.path, coverFileName),
              );
              await files.write(destCover, coverBytes);
              restoredCoverPath =
                  '${AppStorageConstants.coversDir}/$coverFileName';
            } catch (e) {
              appLogger.w(
                '[ImportBackup] Failed to process cover for $hash: $e',
              );
              yield ProgressLog(
                'Warning: Failed to restore cover for "$displayName", skipping cover.',
                ProgressLogType.warning,
              );
            }
          }

          // -- C. Process Manifest JSON --
          final manifestString = await _importService.processPlainFile(
            pathsForBook.manifestPath,
          );
          final manifestMap =
              jsonDecode(manifestString) as Map<String, dynamic>;
          final manifest = decodeManifestBackup(
            manifestMap,
            source: '$hash.json',
          );
          if (manifest.fileHash != hash || manifest.format != format) {
            throw const LibraryException(
              LibraryErrorCode.backupCorrupted,
              '书架与清单的书籍标识或格式不一致',
            );
          }

          // -- D. Build ShelfBook and upsert immediately --
          final book = mapToShelfBook(
            bookMap,
            filePath: '${AppStorageConstants.booksDir}/$bookFileName',
            coverPath: restoredCoverPath,
            format: format,
          );
          await _bookStore.restoreBookWithManifest(book, manifest);
          files.commit();
        } finally {
          await files.close();
        }

        importedCount++;
        appLogger.i(
          '[ImportBackup] Upserted "$displayName" ($importedCount/${booksJson.length}).',
        );

        yield BackupImportProgress(
          current: importedCount,
          total: booksJson.length,
          currentFileName: displayName,
          result: ImportSuccess(importedBooks: importedCount),
        );
      }

      appLogger.i(
        '[ImportBackup] Import complete. Total books: $importedCount',
      );
      yield ProgressLog(
        'Import completed: $importedCount books imported.',
        ProgressLogType.success,
      );
    } on LibraryException catch (e) {
      // 类型化错误（版本过新、备份损坏等）：细节只入日志，文案由错误码映射。
      appLogger.e('[ImportBackup] $e');
      yield failure(e);
    } on FormatException catch (e) {
      appLogger.e('[ImportBackup] JSON parse error: $e');
      yield failure(
        LibraryException(LibraryErrorCode.backupCorrupted, e.message),
      );
    } catch (e, st) {
      appLogger.e('[ImportBackup] Unexpected error: $e\n$st');
      yield failure(LibraryException(LibraryErrorCode.restoreFailed, e));
    } finally {
      // Release all security-scoped resource accesses held by the native iOS
      // picker plugin.  This is a no-op on Android; calling it unconditionally
      // keeps the code simple and guarantees no resource leaks on iOS even if
      // the import fails or is cancelled.
      await _importService.releaseIosAccess();
    }
  }
}
