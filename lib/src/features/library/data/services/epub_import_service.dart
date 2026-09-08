import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/data/services/epub_import_workers.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

import '../book_manifest_repository.dart';
import '../shelf_book_repository.dart';
import 'book_file_probe.dart';
import 'book_file_store.dart';
import 'cover_extractor.dart';

/// Service for importing book files using "stream-from-zip" strategy
/// - EPUB: Copies to AppDocDir/books/{fileHash}.epub (keeps compressed),
///   extracts cover to AppDocDir/covers/{fileHash}.jpg
/// - TXT: 解析后归一化为 UTF-8 写入 AppDocDir/books/{fileHash}.txt，无封面
/// - Parses metadata in-memory (no full unzip)
/// - Saves to drift: ShelfBook + BookManifest
class EpubImportService {
  final ShelfBookRepository _shelfBookRepo;
  final BookManifestRepository _manifestRepo;

  static const _probe = BookFileProbe();
  static const _fileStore = BookFileStore();
  static const _coverExtractor = CoverExtractor();

  EpubImportService({
    required ShelfBookRepository shelfBookRepo,
    required BookManifestRepository manifestRepo,
  }) : _shelfBookRepo = shelfBookRepo,
       _manifestRepo = manifestRepo;

  /// Import a book file (EPUB or TXT) following a clean pipeline pattern
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
      final format = await _probe.detectFormat(file, originalFileName);

      // Pipeline: Hash → Check → Store → Parse → Extract → Create → Save
      final String fileHash =
          precomputedHash ??
          await _probe
              .calculateHash(file)
              .then(
                (result) => result.getOrElse((error) => throw Exception(error)),
              );

      final bookExists = await _checkBookExistence(fileHash);
      if (bookExists.isLeft()) {
        return left(bookExists.getLeft().toNullable()!);
      }

      // 格式分发：TXT 先解析（产出归一化字节）再落盘；EPUB 先落盘再解析。
      final String bookPath;
      final ParseResult parseData;
      String? coverPath;

      if (format == BookFormat.txt) {
        final outcome = await compute(
          ImportWorkers.parseTxt,
          ParseParams(
            filePath: file.path,
            fileHash: fileHash,
            originalFileName: originalFileName ?? file.path.split('/').last,
          ),
        ).then((result) => result.getOrElse((error) => throw Exception(error)));
        parseData = outcome.parseResult;
        bookPath = await _fileStore
            .writeNormalizedTxt(outcome.normalizedBytes, fileHash)
            .then(
              (result) => result.getOrElse((error) => throw Exception(error)),
            );
        coverPath = null;
      } else {
        bookPath = await _fileStore
            .copyBook(file, fileHash, moveSourceFile: moveSourceFile)
            .then(
              (result) => result.getOrElse((error) => throw Exception(error)),
            );

        parseData =
            await _parseAndExtract(
              bookPath,
              fileHash,
              originalFileName ?? file.path.split('/').last,
            ).then((result) async {
              if (result.isLeft()) {
                // 解析失败：清理已落盘的书籍文件再报错
                await _deleteFile(bookPath);
                throw Exception(result.getLeft().toNullable());
              }
              return result.getRight().toNullable()!;
            });

        coverPath = await _coverExtractor.extract(
          epubPath: bookPath,
          fileHash: fileHash,
          coverHref: parseData.coverHref,
          opfRootPath: parseData.opfRootPath,
        );
      }

      final entities = await _createEntities(
        fileHash,
        bookPath,
        coverPath,
        parseData,
        bookExists.getRight().toNullable()!,
      );

      final savedBook =
          await _saveTransaction(
            entities.$1,
            entities.$2,
            bookPath,
            coverPath,
          ).then((result) async {
            if (result.isLeft()) {
              // 保存失败回滚：清理已落盘的书籍文件与封面
              await _deleteFile(bookPath);
              if (coverPath != null) await _deleteFile(coverPath);
              throw Exception(result.getLeft().toNullable());
            }
            return result.getRight().toNullable()!;
          });

      return right(savedBook);
    } catch (e) {
      return left('Import failed: $e');
    }
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
    String bookPath,
    String? coverPath,
    ParseResult parseData,
    bool bookExisted,
  ) async {
    final relativePath = bookPath.replaceAll(AppStorage.documentsPath, '');
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
      format: parseData.format,
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
      format: parseData.format,
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

  /// Delete a file (helper for cleanup)
  Future<Either<String, bool>> _deleteFile(String path) async {
    try {
      // 数据库存的是相对路径，导入管线中的失败回滚拿到的是绝对路径，二者都接受
      final absolutePath = path.startsWith('/')
          ? path
          : '${AppStorage.documentsPath}$path';
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
