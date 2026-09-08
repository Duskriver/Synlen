import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'dart:io';
import 'package:fpdart/fpdart.dart';

import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';
import '../../domain/import_progress.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:path/path.dart' as p;

import '../../domain/book_format.dart';
import '../../domain/book_manifest.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';

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
  final BookManifestRepository _bookManifestRepository;
  final UnifiedImportService _importService;

  ImportBackupService({
    required ShelfBookRepository shelfBookRepository,
    required BookManifestRepository bookManifestRepository,
    required UnifiedImportService importService,
  }) : _shelfBookRepository = shelfBookRepository,
       _bookManifestRepository = bookManifestRepository,
       _importService = importService;

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
    BackupImportProgress failure(String message) => BackupImportProgress(
      current: importedCount,
      total: totalCount,
      currentFileName: currentFileName,
      result: ImportFailure(message),
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

      final groupsJson = (shelfJson['groups'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final booksJson = (shelfJson['books'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
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
        final groups = groupsJson.map(_mapToShelfGroup).toList();
        await _mergeGroup(groups);
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
          throw StateError('备份缺少书籍或清单：$hash');
        }

        // -- A. Process & Copy book file --
        final destBook = File(p.join(internalBooksDir.path, bookFileName));
        if (!destBook.existsSync()) {
          final importableBook = await _importService.processEpub(
            pathsForBook.epubPath,
          );
          try {
            await importableBook.cacheFile.copy(destBook.path);
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
            await destCover.writeAsBytes(coverBytes);
            restoredCoverPath =
                '${AppStorageConstants.coversDir}/$coverFileName';
          } catch (e) {
            appLogger.w('[ImportBackup] Failed to process cover for $hash: $e');
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
        final manifestMap = jsonDecode(manifestString) as Map<String, dynamic>;
        final manifest = _mapToBookManifest(manifestMap);
        if (manifest.fileHash != hash || manifest.format != format) {
          throw const FormatException('书架与清单的书籍标识或格式不一致');
        }
        await _mergeManifest(manifest);

        // -- D. Build ShelfBook and upsert immediately --
        final book = _mapToShelfBook(
          bookMap,
          filePath: '${AppStorageConstants.booksDir}/$bookFileName',
          coverPath: restoredCoverPath,
          format: format,
        );
        await _mergeBook(book);

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
    } on FormatException catch (e) {
      appLogger.e('[ImportBackup] JSON parse error: $e');
      yield failure('Failed to parse backup data: ${e.message}');
    } catch (e, st) {
      appLogger.e('[ImportBackup] Unexpected error: $e\n$st');
      yield failure('Import failed: $e');
    } finally {
      // Release all security-scoped resource accesses held by the native iOS
      // picker plugin.  This is a no-op on Android; calling it unconditionally
      // keeps the code simple and guarantees no resource leaks on iOS even if
      // the import fails or is cancelled.
      await _importService.releaseIosAccess();
    }
  }

  Future<void> _mergeGroup(List<ShelfGroup> backupGroups) async {
    for (final backupGroup in backupGroups) {
      final existingGroup = await _shelfBookRepository.getGroupByName(
        backupGroup.name,
      );

      if (existingGroup == null) {
        final id = _requireSaved(
          await _shelfBookRepository.createGroup(name: backupGroup.name),
        );
        await _shelfBookRepository.saveGroup(backupGroup.copyWith(id: id));
      } else {
        if (backupGroup.updatedAt > existingGroup.updatedAt) {
          await _shelfBookRepository.saveGroup(
            backupGroup.copyWith(id: existingGroup.id),
          );
        }
      }
    }
  }

  T _requireSaved<T>(Either<String, T> result) =>
      result.fold((error) => throw StateError(error), (value) => value);

  /// Drift 的 dateTime 列按秒存储；毫秒差会被截断，必须按同一精度比较，
  /// 否则同秒内的旧备份会被误判为较新。
  bool _isManifestNewer(DateTime backup, DateTime existing) =>
      backup.millisecondsSinceEpoch ~/ 1000 >
      existing.millisecondsSinceEpoch ~/ 1000;

  Future<void> _mergeManifest(BookManifest backupManifest) async {
    final existing = await _bookManifestRepository.getManifestByHash(
      backupManifest.fileHash,
    );
    if (existing != null &&
        !_isManifestNewer(backupManifest.lastUpdated, existing.lastUpdated)) {
      return;
    }
    _requireSaved(
      await _bookManifestRepository.saveManifest(
        backupManifest.copyWith(id: existing?.id ?? 0),
      ),
    );
  }

  Future<void> _mergeBook(ShelfBook backupBook) async {
    final existing = await _shelfBookRepository.getBookByHash(
      backupBook.fileHash,
    );
    if (existing == null) {
      _requireSaved(await _shelfBookRepository.saveBook(backupBook));
      return;
    }

    // 元数据与阅读位置分别按各自时间选择；相同或都未知时保留本机值。
    final metadata = backupBook.updatedAt > existing.updatedAt
        ? backupBook
        : existing;
    final backupReadAt = backupBook.lastOpenedDate;
    final localReadAt = existing.lastOpenedDate;
    final progress =
        backupReadAt != null &&
            (localReadAt == null || backupReadAt > localReadAt)
        ? backupBook
        : existing;
    final merged = metadata.copyWith(
      id: existing.id,
      filePath: Value(backupBook.filePath),
      coverPath: Value(metadata.coverPath ?? existing.coverPath),
      currentChapterIndex: progress.currentChapterIndex,
      readingProgress: progress.readingProgress,
      chapterScrollPosition: Value(progress.chapterScrollPosition),
      isFinished: progress.isFinished,
      lastOpenedDate: Value(progress.lastOpenedDate),
      // 显式恢复包含此书的备份时撤销本机软删除，同时保留选定的较新数据。
      isDeleted: backupBook.isDeleted && metadata.isDeleted,
    );
    _requireSaved(await _shelfBookRepository.saveBook(merged));
  }

  // ---------------------------------------------------------------------------
  // Reverse-mapping helpers (JSON → domain objects)
  // ---------------------------------------------------------------------------

  /// Deserialises a [ShelfGroup] from its JSON map.
  /// The `id` field is intentionally 0 — drift assigns it on insert, and the
  /// merge logic preserves the existing row if the group already exists.
  ShelfGroup _mapToShelfGroup(Map<String, dynamic> m) {
    return ShelfGroup(
      id: 0,
      name: m['name'] as String,
      creationDate: m['creationDate'] as int,
      updatedAt: m['updatedAt'] as int,
      isDeleted: m['isDeleted'] as bool? ?? false,
    );
  }

  /// Deserialises a [ShelfBook] from its JSON map.
  ///
  /// [filePath] and [coverPath] are injected from the just-copied files rather
  /// than taken from JSON, because the JSON deliberately excludes them (they
  /// are device-specific absolute paths).
  ShelfBook _mapToShelfBook(
    Map<String, dynamic> m, {
    required String? filePath,
    required String? coverPath,
    required BookFormat format,
  }) {
    return ShelfBook(
      id: 0,
      fileHash: m['fileHash'] as String,
      filePath: filePath,
      coverPath: coverPath,
      title: m['title'] as String,
      author: m['author'] as String,
      authors: (m['authors'] as List<dynamic>).cast<String>(),
      description: m['description'] as String?,
      subjects: (m['subjects'] as List<dynamic>).cast<String>(),
      totalChapters: m['totalChapters'] as int,
      epubVersion: m['epubVersion'] as String,
      format: format,
      importDate: m['importDate'] as int,
      currentChapterIndex: m['currentChapterIndex'] as int? ?? 0,
      readingProgress: (m['readingProgress'] as num? ?? 0.0).toDouble(),
      chapterScrollPosition: (m['chapterScrollPosition'] as num?)?.toDouble(),
      lastOpenedDate: m['lastOpenedDate'] as int?,
      isFinished: m['isFinished'] as bool? ?? false,
      groupName: m['groupName'] as String?,
      isDeleted: m['isDeleted'] as bool? ?? false,
      updatedAt: m['updatedAt'] as int,
      lastSyncedDate: m['lastSyncedDate'] as int?,
      direction: m['direction'] as int? ?? 0,
    );
  }

  /// Deserialises a full [BookManifest] (including all embedded objects).
  BookManifest _mapToBookManifest(Map<String, dynamic> m) {
    return BookManifest(
      id: 0,
      fileHash: m['fileHash'] as String,
      opfRootPath: m['opfRootPath'] as String,
      epubVersion: m['epubVersion'] as String,
      format: BookFormat.values.asNameMap()[m['format']] ?? BookFormat.epub,
      lastUpdated: DateTime.parse(m['lastUpdated'] as String),
      spine: (m['spine'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_mapToSpineItem)
          .toList(),
      toc: (m['toc'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_mapToTocItem)
          .toList(),
      manifest: (m['manifest'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_mapToManifestItem)
          .toList(),
    );
  }

  SpineItem _mapToSpineItem(Map<String, dynamic> m) {
    return SpineItem(
      index: m['index'] as int,
      // In SpineItem, `href` is a plain String (file path relative to OPF root).
      href: m['href'] as String,
      idref: m['idref'] as String,
      linear: m['linear'] as bool? ?? true,
      properties: m['properties'] as String?,
      sourceRange: m['sourceRange'] as String?,
    );
  }

  Href _mapToHref(Map<String, dynamic> m) {
    return Href()
      ..path = m['path'] as String
      ..anchor = m['anchor'] as String? ?? 'top';
  }

  ManifestItem _mapToManifestItem(Map<String, dynamic> m) {
    return ManifestItem()
      ..id = m['id'] as String
      ..href = _mapToHref(m['href'] as Map<String, dynamic>)
      ..mediaType = m['mediaType'] as String
      ..properties = m['properties'] as String?;
  }

  TocItem _mapToTocItem(Map<String, dynamic> m) {
    return TocItem()
      ..id = m['id'] as int
      ..label = m['label'] as String
      ..href = _mapToHref(m['href'] as Map<String, dynamic>)
      ..depth = m['depth'] as int
      ..spineIndex = m['spineIndex'] as int? ?? -1
      ..parentId = m['parentId'] as int
      ..children = (m['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_mapToTocItem)
          .toList();
  }
}
