import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import 'package:synlen/src/features/library/data/services/epub_import_workers.dart';
import 'package:synlen/src/rust/api/epub.dart' as rust_epub;
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import '../shelf_book_repository.dart';
import '../book_manifest_repository.dart';

/// Service for importing EPUB files using "stream-from-zip" strategy
/// - Copies EPUB to AppDocDir/books/{fileHash}.epub (keeps compressed)
/// - Extracts cover to AppDocDir/covers/{fileHash}.jpg
/// - Parses metadata in-memory (no full unzip)
/// - Saves to drift: ShelfBook + BookManifest
class EpubImportService {
  final ShelfBookRepository _shelfBookRepo;
  final BookManifestRepository _manifestRepo;

  EpubImportService({
    required ShelfBookRepository shelfBookRepo,
    required BookManifestRepository manifestRepo,
  }) : _shelfBookRepo = shelfBookRepo,
       _manifestRepo = manifestRepo;

  /// Import an EPUB file following a clean pipeline pattern
  /// Returns Either:
  ///   - Right: The imported ShelfBook
  ///   - Left: error message
  Future<Either<String, ShelfBook>> importBook(
    File file, {
    String? precomputedHash,
    String? originalFileName,
    bool moveSourceFile = false,
  }) async {
    try {
      // Pipeline: Hash → Check → Copy → Parse → Extract → Create → Save
      final String fileHash =
          precomputedHash ??
          await _calculateHash(file).then(
            (result) => result.getOrElse((error) => throw Exception(error)),
          );

      final bookExists = await _checkBookExistence(fileHash);
      if (bookExists.isLeft()) {
        return left(bookExists.getLeft().toNullable()!);
      }

      final epubPath = await _copyToAppStorage(
        file,
        fileHash,
        moveSourceFile: moveSourceFile,
      ).then((result) => result.getOrElse((error) => throw Exception(error)));

      final parseData =
          await _parseAndExtract(
            epubPath,
            fileHash,
            originalFileName ?? file.path.split('/').last,
          ).then(
            (result) => result.fold((error) {
              _deleteFile(epubPath);
              throw Exception(error);
            }, (data) => data),
          );

      final coverPath = await _extractCover(
        epubPath,
        fileHash,
        parseData.coverHref,
        parseData.opfRootPath,
      );

      final entities = await _createEntities(
        fileHash,
        epubPath,
        coverPath,
        parseData,
        bookExists.getRight().toNullable()!,
      );

      final savedBook =
          await _saveTransaction(
            entities.$1,
            entities.$2,
            epubPath,
            coverPath,
          ).then(
            (result) => result.fold((error) {
              _deleteFile(epubPath);
              if (coverPath != null) _deleteFile(coverPath);
              throw Exception(error);
            }, (book) => book),
          );

      return right(savedBook);
    } catch (e) {
      return left('Import failed: $e');
    }
  }

  /// Calculate file hash using isolate
  Future<Either<String, String>> _calculateHash(File file) async {
    return compute(ImportWorkers.calculateFileHash, file.path);
  }

  /// Check if book already exists
  /// Returns Either:
  ///   - Left: error (book already exists)
  ///   - Right: true if book exists but deleted, false if never existed
  Future<Either<String, bool>> _checkBookExistence(String fileHash) async {
    final existsAndNotDeleted = await _shelfBookRepo.bookExistsAndNotDeleted(
      fileHash,
    );
    if (existsAndNotDeleted) {
      return left('Book already exists');
    }

    final exists = await _shelfBookRepo.bookExists(fileHash);
    return right(exists);
  }

  /// Parse EPUB and extract metadata using isolate
  Future<Either<String, ParseResult>> _parseAndExtract(
    String epubPath,
    String fileHash,
    String originalFileName,
  ) async {
    return compute(
      ImportWorkers.parseEpub,
      ParseParams(
        filePath: epubPath,
        fileHash: fileHash,
        originalFileName: originalFileName,
      ),
    );
  }

  /// Create ShelfBook and BookManifest entities
  /// Returns tuple (ShelfBook, BookManifest)
  Future<(ShelfBook, BookManifest)> _createEntities(
    String fileHash,
    String epubPath,
    String? coverPath,
    ParseResult parseData,
    bool bookExisted,
  ) async {
    final relativePath = epubPath.replaceAll(AppStorage.documentsPath, '');
    final now = DateTime.now().millisecondsSinceEpoch;

    final existingId = bookExisted
        ? await _shelfBookRepo.getBookIdByHash(fileHash)
        : null;

    final shelfBook = ShelfBook(
      id: existingId ?? 0,
      fileHash: fileHash,
      filePath: relativePath,
      coverPath: coverPath,
      title: parseData.title,
      author: parseData.author,
      authors: parseData.authors,
      description: parseData.description,
      subjects: parseData.subjects,
      totalChapters: parseData.totalChapters,
      epubVersion: parseData.epubVersion,
      importDate: now,
      updatedAt: now,
      direction: parseData.readDirection,
      currentChapterIndex: 0,
      readingProgress: 0.0,
      isFinished: false,
      isDeleted: false,
    );

    final manifest = BookManifest(
      id: 0,
      fileHash: fileHash,
      opfRootPath: parseData.opfRootPath,
      spine: parseData.spine,
      toc: parseData.toc,
      manifest: parseData.manifestItems,
      epubVersion: parseData.epubVersion,
      lastUpdated: DateTime.now(),
    );

    return (shelfBook, manifest);
  }

  /// Save ShelfBook and BookManifest in a transactional manner
  /// Rollback on failure
  Future<Either<String, ShelfBook>> _saveTransaction(
    ShelfBook shelfBook,
    BookManifest manifest,
    String epubPath,
    String? coverPath,
  ) async {
    final saveBookResult = await _shelfBookRepo.saveBook(shelfBook);
    if (saveBookResult.isLeft()) {
      return left(saveBookResult.getLeft().toNullable()!);
    }

    final bookId = saveBookResult.getRight().toNullable()!;

    final saveManifestResult = await _manifestRepo.saveManifest(manifest);
    if (saveManifestResult.isLeft()) {
      // Rollback: delete ShelfBook
      await _shelfBookRepo.deleteBook(bookId);
      return left(saveManifestResult.getLeft().toNullable()!);
    }

    // 更新 book 的数据库 ID
    return right(shelfBook.copyWith(id: bookId));
  }

  /// Copy EPUB file to books directory
  /// Returns absolute path to the copied file
  Future<Either<String, String>> _copyToAppStorage(
    File sourceFile,
    String fileHash, {
    bool moveSourceFile = false,
  }) async {
    try {
      final booksDir = Directory(
        '${AppStorage.documentsPath}${AppStorageConstants.booksDir}',
      );
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final targetPath = '${booksDir.path}/$fileHash.epub';
      final targetFile = File(targetPath);

      // Check if file already exists (edge case)
      if (await targetFile.exists()) {
        return right(targetPath);
      }

      if (moveSourceFile) {
        try {
          await sourceFile.rename(targetPath);
        } on FileSystemException {
          await sourceFile.copy(targetPath);
        }
      } else {
        await sourceFile.copy(targetPath);
      }
      return right(targetPath);
    } catch (e) {
      return left('File copy failed: $e');
    }
  }

  /// Extract cover image from EPUB and save to covers directory
  /// Returns relative path to the cover image, or null if no cover found
  Future<String?> _extractCover(
    String epubPath,
    String fileHash,
    String? coverHref,
    String opfRootPath,
  ) async {
    if (coverHref == null || coverHref.isEmpty) {
      return null;
    }

    try {
      final coversDir = Directory(
        '${AppStorage.documentsPath}${AppStorageConstants.coversDir}',
      );
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Resolve cover path relative to the OPF root, then read only that entry
      // through the Rust EPUB backend instead of scanning the whole ZIP in Dart.
      final opfDir = opfRootPath.contains('/')
          ? opfRootPath.substring(0, opfRootPath.lastIndexOf('/'))
          : '';
      final coverPath = opfDir.isEmpty ? coverHref : '$opfDir/$coverHref';

      // Determine file extension from MIME type or filename
      var extension = _getImageExtension(coverPath);

      await rust_epub.loadEpub(epubPath: epubPath);
      final rawCoverData = await rust_epub.readEpubFile(
        epubPath: epubPath,
        filePath: coverPath,
      );
      if (rawCoverData == null || rawCoverData.isEmpty) {
        return null;
      }

      // Compress image using worker
      var coverData = await ImportWorkers.compressImage(rawCoverData);
      if (coverData != null) {
        extension = '.jpg';
      } else {
        coverData = rawCoverData;
      }

      final outputPath = '${coversDir.path}/$fileHash$extension';
      await File(outputPath).writeAsBytes(coverData as List<int>);

      return '${AppStorageConstants.coversDir}/$fileHash$extension';
    } catch (e) {
      // Cover extraction is non-critical, log and continue
      debugPrint('Cover extraction failed: $e');
      return null;
    } finally {
      rust_epub.closeEpub(epubPath: epubPath).ignore();
    }
  }

  /// Get image extension from filename
  String _getImageExtension(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return '.jpg';
    } else if (lower.endsWith('.png')) {
      return '.png';
    } else if (lower.endsWith('.gif')) {
      return '.gif';
    } else if (lower.endsWith('.webp')) {
      return '.webp';
    } else if (lower.endsWith('.bmp')) {
      return '.bmp';
    } else if (lower.endsWith('.svg')) {
      return '.svg';
    }
    final specifiedExtension = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.'))
        : null;
    return specifiedExtension ?? '.jpg'; // Default
  }

  /// Delete a file (helper for cleanup)
  Future<Either<String, bool>> _deleteFile(String path) async {
    try {
      final absolutePath = '${AppStorage.documentsPath}$path';
      final file = File(absolutePath);
      if (await file.exists()) {
        await file.delete();
        return right(true);
      }
      return right(false);
    } catch (e) {
      return left('Failed to delete file $path: $e');
    }
  }

  Future<Either<String, bool>> _rollbackDeleteFailure({
    required String message,
    required ShelfBook book,
    required bool originalDeletedState,
    required bool bookWasSoftDeleted,
    required BookManifest? originalManifest,
    required bool manifestWasDeleted,
  }) async {
    final rollbackErrors = <String>[];

    if (manifestWasDeleted && originalManifest != null) {
      final restoreManifestResult = await _manifestRepo.saveManifest(
        originalManifest,
      );
      if (restoreManifestResult.isLeft()) {
        rollbackErrors.add(
          'Restore manifest failed: ${restoreManifestResult.getLeft().toNullable()!}',
        );
      }
    }

    if (bookWasSoftDeleted) {
      final restoredBook = book.copyWith(
        isDeleted: originalDeletedState,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      final restoreBookResult = await _shelfBookRepo.saveBook(restoredBook);
      if (restoreBookResult.isLeft()) {
        rollbackErrors.add(
          'Restore book failed: ${restoreBookResult.getLeft().toNullable()!}',
        );
      }
    }

    if (rollbackErrors.isEmpty) {
      return left(message);
    }

    return left('$message (rollback errors: ${rollbackErrors.join('; ')})');
  }

  /// Delete imported book (ShelfBook + BookManifest + files)
  Future<Either<String, bool>> deleteBook(ShelfBook book) async {
    final originalDeletedState = book.isDeleted;
    final originalManifest = await _manifestRepo.getManifestByHash(
      book.fileHash,
    );
    var bookWasSoftDeleted = false;
    var manifestWasDeleted = false;

    try {
      final softDeleteResult = await _shelfBookRepo.softDeleteBook(book.id);
      if (softDeleteResult.isLeft()) {
        return left(softDeleteResult.getLeft().toNullable()!);
      }
      if (softDeleteResult.getRight().toNullable() != true) {
        return left('Delete book failed: book record was not updated');
      }
      bookWasSoftDeleted = true;

      final deleteManifestResult = await _manifestRepo.deleteManifestByHash(
        book.fileHash,
      );
      if (deleteManifestResult.isLeft()) {
        return _rollbackDeleteFailure(
          message: deleteManifestResult.getLeft().toNullable()!,
          book: book,
          originalDeletedState: originalDeletedState,
          bookWasSoftDeleted: bookWasSoftDeleted,
          originalManifest: originalManifest,
          manifestWasDeleted: manifestWasDeleted,
        );
      }
      final didDeleteManifest = deleteManifestResult.getRight().toNullable()!;
      if (!didDeleteManifest && originalManifest != null) {
        return _rollbackDeleteFailure(
          message: 'Delete manifest failed: manifest record still exists',
          book: book,
          originalDeletedState: originalDeletedState,
          bookWasSoftDeleted: bookWasSoftDeleted,
          originalManifest: originalManifest,
          manifestWasDeleted: manifestWasDeleted,
        );
      }
      manifestWasDeleted = didDeleteManifest;

      // Delete files after metadata is removed so a failed rollback favors
      // keeping the primary EPUB file over the derived cover image.
      if (book.coverPath != null) {
        final coverDeleteResult = await _deleteFile(book.coverPath!);
        if (coverDeleteResult.isLeft()) {
          return _rollbackDeleteFailure(
            message: coverDeleteResult.getLeft().toNullable()!,
            book: book,
            originalDeletedState: originalDeletedState,
            bookWasSoftDeleted: bookWasSoftDeleted,
            originalManifest: originalManifest,
            manifestWasDeleted: manifestWasDeleted,
          );
        }
      }
      if (book.filePath != null) {
        final bookFileDeleteResult = await _deleteFile(book.filePath!);
        if (bookFileDeleteResult.isLeft()) {
          return _rollbackDeleteFailure(
            message: bookFileDeleteResult.getLeft().toNullable()!,
            book: book,
            originalDeletedState: originalDeletedState,
            bookWasSoftDeleted: bookWasSoftDeleted,
            originalManifest: originalManifest,
            manifestWasDeleted: manifestWasDeleted,
          );
        }
      }

      return right(true);
    } catch (e) {
      return _rollbackDeleteFailure(
        message: 'Delete book failed: $e',
        book: book,
        originalDeletedState: originalDeletedState,
        bookWasSoftDeleted: bookWasSoftDeleted,
        originalManifest: originalManifest,
        manifestWasDeleted: manifestWasDeleted,
      );
    }
  }
}
