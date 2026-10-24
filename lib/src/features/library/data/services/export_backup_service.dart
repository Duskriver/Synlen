import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:archive/archive_io.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../domain/book_manifest.dart';
import '../../domain/library_exception.dart';

import 'package:synlen/src/core/database/app_database.dart';

import '../book_manifest_repository.dart';
import '../shelf_book_repository.dart';

import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import 'backup_decoders.dart';

/// Result of an export operation.
sealed class ExportResult {
  const ExportResult();
}

/// Export succeeded and the backup file was handed to the system share sheet.
final class ExportSuccess extends ExportResult {
  const ExportSuccess();
}

/// 分享失败或被取消；内部详情只写日志。
final class ExportFailure extends ExportResult {
  final LibraryErrorCode code;
  const ExportFailure(this.code);
}

/// Library backup export service.
///
/// 所有平台统一：先在应用临时目录拼装备份文件夹（shelf.json + 书籍/封面/
/// 清单），再压缩成单个 ZIP 通过系统分享面板交由用户保存。应用私有缓存目录
/// 的写入不需要任何存储权限，Android 分区存储与 iOS 均适用；分享面板由
/// share_plus 的 FileProvider 提供，也不触碰公共存储。
///
/// Memory profile:
///   Physical files (.epub, cover images) are transferred with [File.copy]
///   which is a kernel-level operation — no bytes are ever loaded into the
///   Dart heap.  ZIP 压缩由 [ZipFileEncoder] 流式写出，只有 JSON 载荷
///   （manifest + shelf 元数据）进入内存，且刻意保持很小。
class ExportBackupService {
  static const _kBackupTempDir = 'backup';

  final ShelfBookRepository _shelfBookRepo;
  final BookManifestRepository _manifestRepo;
  final Future<ShareResult> Function(ShareParams params) _share;

  ExportBackupService({
    required this._shelfBookRepo,
    required this._manifestRepo,
    Future<ShareResult> Function(ShareParams params)? share,
  }) : _share = share ?? ((params) => SharePlus.instance.share(params));

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Exports the entire library as a single ZIP backup and hands it to the
  /// system share sheet ([shareTitle] anchors iOS popover to
  /// [sharePositionOrigin]).
  ///
  /// 分享成功返回 [ExportSuccess]，未完成分享返回 [ExportFailure]。
  /// I/O 与平台异常交给 application 转换；临时文件始终清理。
  Future<ExportResult> exportLibraryAsFile({
    Rect? sharePositionOrigin,
    required String shareTitle,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupName = 'synlen-backup-$timestamp';
    Directory? targetDir;
    File? zipFile;

    try {
      // -----------------------------------------------------------------------
      // 1. Assemble the backup folder inside the app-private temp directory.
      // -----------------------------------------------------------------------
      targetDir = Directory(
        p.join(AppStorage.tempPath, _kBackupTempDir, backupName),
      );

      // -----------------------------------------------------------------------
      // 2. Create sub-directories.
      // -----------------------------------------------------------------------
      final booksOutDir = await Directory(
        p.join(targetDir.path, AppStorageConstants.booksDir),
      ).create(recursive: true);
      final coversOutDir = await Directory(
        p.join(targetDir.path, AppStorageConstants.coversDir),
      ).create(recursive: true);
      final manifestsOutDir = await Directory(
        p.join(targetDir.path, AppStorageConstants.manifestsDir),
      ).create(recursive: true);

      // -----------------------------------------------------------------------
      // 3. Fetch all books and groups from the database.
      // -----------------------------------------------------------------------
      final books = await _shelfBookRepo.getAllBooks();
      final groups = await _shelfBookRepo.getGroups();

      // -----------------------------------------------------------------------
      // 4. Per-book: copy physical files & serialise manifests.
      // -----------------------------------------------------------------------
      for (final book in books) {
        final hash = book.fileHash;
        final bookFileName = '$hash${book.format.fileExtension}';

        // -- Copy book file (zero-memory: kernel copy, no Dart byte buffers) ---
        final bookSrc = File(
          p.join(
            AppStorage.documentsPath,
            AppStorageConstants.booksDir,
            bookFileName,
          ),
        );
        if (bookSrc.existsSync()) {
          await bookSrc.copy(p.join(booksOutDir.path, bookFileName));
        } else {
          appLogger.w(
            '[ExportBackup] Book file not found, skipping: ${bookSrc.path}',
          );
        }

        final coverSrc = _coverFile(book);
        if (coverSrc != null && coverSrc.existsSync()) {
          final extension = p.extension(coverSrc.path);
          // 恢复按哈希关联封面，备份文件名不能沿用任意源文件名。
          final coverName = '$hash${extension.isEmpty ? '.jpg' : extension}';
          await coverSrc.copy(p.join(coversOutDir.path, coverName));
        } else {
          appLogger.w('[ExportBackup] Cover not found, skipping: $hash');
        }

        // -- Serialise BookManifest to JSON ------------------------------------
        final manifest = await _manifestRepo.getManifestByHash(hash);
        if (manifest != null) {
          final manifestJson = jsonEncode(_manifestToMap(manifest));
          await File(p.join(manifestsOutDir.path, '$hash.json'))
              .writeAsString(manifestJson);
        } else {
          appLogger.w('[ExportBackup] No manifest found for: $hash');
        }
      }

      // -----------------------------------------------------------------------
      // 5. Write shelf.json (ShelfBooks + ShelfGroups).
      // -----------------------------------------------------------------------
      final shelfMap = _shelfToMap(books, groups);
      final shelfJson = jsonEncode(shelfMap);
      await File(p.join(targetDir.path, AppStorageConstants.shelfFile))
          .writeAsString(shelfJson);

      // -----------------------------------------------------------------------
      // 6. Zip the folder (streamed, bounded memory) and share the file.
      // -----------------------------------------------------------------------
      zipFile = File(p.join(targetDir.parent.path, '$backupName.zip'));
      final encoder = ZipFileEncoder();
      await encoder.zipDirectory(targetDir, filename: zipFile.path);

      final result = await _share(
        ShareParams(
          files: [
            XFile(
              zipFile.path,
              mimeType: 'application/zip',
              name: p.basename(zipFile.path),
            ),
          ],
          title: shareTitle,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      appLogger.i('[ExportBackup] Share result: $result');
      switch (result.status) {
        case ShareResultStatus.success:
          return const ExportSuccess();
        case ShareResultStatus.dismissed:
          appLogger.i('[ExportBackup] Export cancelled by user.');
          return const ExportFailure(LibraryErrorCode.exportCancelled);
        default:
          appLogger.e('[ExportBackup] Export failed: ${result.raw}');
          return const ExportFailure(LibraryErrorCode.exportFailed);
      }
    } finally {
      // -----------------------------------------------------------------------
      // 7. Cleanup — the folder and ZIP live in the app-private temp
      //    directory and are obsolete once the share sheet has copies.
      // -----------------------------------------------------------------------
      for (final entity in [targetDir, zipFile]) {
        try {
          if (entity != null && entity.existsSync()) {
            await entity.delete(recursive: true);
            appLogger.d('[ExportBackup] Cleaned up ${entity.path}.');
          }
        } catch (e) {
          appLogger.w('[ExportBackup] Cleanup failed (non-fatal): $e');
        }
      }
    }
  }

  File? _coverFile(ShelfBook book) {
    final coverPath = book.coverPath;
    if (coverPath != null && coverPath.isNotEmpty) {
      return File(p.join(AppStorage.documentsPath, coverPath));
    }
    // 兼容缺少 coverPath 的旧书目。
    for (final extension in ['jpg', 'png', 'jpeg', 'webp']) {
      final file = File(
        p.join(
          AppStorage.documentsPath,
          AppStorageConstants.coversDir,
          '${book.fileHash}.$extension',
        ),
      );
      if (file.existsSync()) return file;
    }
    return null;
  }

  /// 删除残留的导出临时目录；目录位于应用缓存区，随时可安全重建。
  Future<void> clearCache() async {
    final targetDir = Directory(p.join(AppStorage.tempPath, _kBackupTempDir));
    try {
      if (targetDir.existsSync()) {
        await targetDir.delete(recursive: true);
        appLogger.d('[ExportBackup] Cache cleared successfully.');
      }
    } catch (e) {
      appLogger.w('[ExportBackup] Cache clearing failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // JSON Mapping helpers
  // ---------------------------------------------------------------------------

  /// Serialises the entire shelf (books + groups) to a JSON-compatible map.
  Map<String, dynamic> _shelfToMap(
    List<ShelfBook> books,
    List<ShelfGroup> groups,
  ) => {
    'version': kBackupFormatVersion, // 恢复端据此分派 decoder
    'books': books.map(_shelfBookToMap).toList(),
    'groups': groups.map(_shelfGroupToMap).toList(),
  };

  /// Serialises [ShelfBook] to a JSON-compatible map.
  ///
  /// Intentionally excludes:
  ///   - [id]         — drift auto-increment，仅在当前设备内有意义。
  ///   - [filePath]   — Absolute device path; would break on a different device.
  ///   - [coverPath]  — Same reason as filePath.
  Map<String, dynamic> _shelfBookToMap(ShelfBook b) => {
    'fileHash': b.fileHash,
    'title': b.title,
    'author': b.author,
    'authors': b.authors,
    'description': b.description,
    'subjects': b.subjects,
    'totalChapters': b.totalChapters,
    'epubVersion': b.epubVersion,
    'format': b.format.name,
    'importDate': b.importDate,
    'progress': b.progress?.toJson(),
    'readingProgress': b.readingProgress,
    'lastOpenedDate': b.lastOpenedDate,
    'isFinished': b.isFinished,
    'groupName': b.groupName,
    'isDeleted': b.isDeleted,
    'updatedAt': b.updatedAt,
    'lastSyncedDate': b.lastSyncedDate,
    'direction': b.direction,
  };

  /// Serialises [ShelfGroup] to a JSON-compatible map.
  ///
  /// Excludes [id] for the same reason as [ShelfBook].
  Map<String, dynamic> _shelfGroupToMap(ShelfGroup g) => {
    'name': g.name,
    'creationDate': g.creationDate,
    'updatedAt': g.updatedAt,
    'isDeleted': g.isDeleted,
  };

  /// Serialises the full [BookManifest] (and all embedded objects) to a map.
  ///
  /// Excludes [id] — the [fileHash] is the canonical identifier.
  Map<String, dynamic> _manifestToMap(BookManifest m) => {
    'version': kBackupFormatVersion, // 恢复端据此分派 decoder
    'fileHash': m.fileHash,
    'opfRootPath': m.opfRootPath,
    'epubVersion': m.epubVersion,
    'format': m.format.name,
    'lastUpdated': m.lastUpdated.toIso8601String(),
    'spine': m.spine.map(_spineItemToMap).toList(),
    'toc': m.toc.map(_tocItemToMap).toList(),
    'manifest': m.manifest.map(_manifestItemToMap).toList(),
  };

  Map<String, dynamic> _spineItemToMap(SpineItem s) => {
    'index': s.index,
    'href': s.href,
    'idref': s.idref,
    'linear': s.linear,
    'properties': s.properties,
    'sourceRange': s.sourceRange,
  };

  Map<String, dynamic> _hrefToMap(Href h) => {
    'path': h.path,
    'anchor': h.anchor,
  };

  Map<String, dynamic> _manifestItemToMap(ManifestItem item) => {
    'id': item.id,
    'href': _hrefToMap(item.href),
    'mediaType': item.mediaType,
    'properties': item.properties,
  };

  Map<String, dynamic> _tocItemToMap(TocItem t) => {
    'id': t.id,
    'label': t.label,
    'href': _hrefToMap(t.href),
    'depth': t.depth,
    'spineIndex': t.spineIndex,
    'parentId': t.parentId,
    'children': t.children.map(_tocItemToMap).toList(),
  };
}
