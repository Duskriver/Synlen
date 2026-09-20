import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/data/services/epub_import_workers.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

import '../parsers/epub_zip_parser.dart';
import '../library_book_store.dart';
import '../shelf_book_repository.dart';
import 'book_file_probe.dart';
import 'book_file_store.dart';
import 'book_file_changes.dart';
import 'cover_extractor.dart';

/// Service for importing book files using "stream-from-zip" strategy
/// - EPUB: Copies to AppDocDir/books/{fileHash}.epub (keeps compressed),
///   extracts cover to AppDocDir/covers/{fileHash}.jpg
/// - TXT: 解析后归一化为 UTF-8 写入 AppDocDir/books/{fileHash}.txt，无封面
/// - Parses metadata in-memory (no full unzip)
/// - Saves to drift: ShelfBook + BookManifest 在同一事务中双写
class BookImportService {
  final ShelfBookRepository _shelfBookRepo;
  final LibraryBookStore _libraryBookStore;

  static const _probe = BookFileProbe();
  final BookFileStore _fileStore;
  static const _coverExtractor = CoverExtractor();

  BookImportService({
    required ShelfBookRepository shelfBookRepo,
    required LibraryBookStore libraryBookStore,
    required BookFileStore fileStore,
  }) : _shelfBookRepo = shelfBookRepo,
       _libraryBookStore = libraryBookStore,
       _fileStore = fileStore;

  /// Import a book file (EPUB or TXT) following a clean pipeline pattern
  /// [precomputedHash] 为调用方预先算好的 SHA-256 hex 哈希，与导入缓存、
  /// 备份清单共用同一编码
  /// Returns Either:
  ///   - Right: The imported ShelfBook
  ///   - Left: 类型化错误（用户文案由 presentation 按错误码映射）
  Future<Either<LibraryException, ShelfBook>> importBook(
    File file, {
    required String precomputedHash,
    String? originalFileName,
    bool moveSourceFile = false,
  }) async {
    final files = BookFileChanges();
    try {
      final format = await _probe.detectFormat(file, originalFileName);

      // Pipeline: Hash → Check → Store → Parse → Extract → Create → Save
      final String fileHash = precomputedHash;

      final bookExists = await _checkBookExistence(fileHash);
      if (bookExists.isLeft()) {
        return left(bookExists.getLeft().toNullable()!);
      }

      // 格式分发：TXT 先解析（产出归一化字节）再落盘；EPUB 先落盘再解析。
      final String bookPath;
      final EpubZipParseResult parseData;
      String? coverPath;

      if (format == BookFormat.txt) {
        final outcome = await compute(
          ImportWorkers.parseTxt,
          ParseParams(
            filePath: file.path,
            fileHash: fileHash,
            originalFileName: originalFileName ?? file.path.split('/').last,
          ),
        ).then((result) => result.getOrElse((error) => throw error));
        parseData = outcome.parseResult;
        bookPath = await _fileStore
            .writeNormalizedTxt(
              outcome.normalizedBytes,
              fileHash,
              changes: files,
            )
            .then((result) => result.getOrElse((error) => throw error));
        coverPath = null;
      } else {
        bookPath = await _fileStore
            .copyBook(
              file,
              fileHash,
              moveSourceFile: moveSourceFile,
              changes: files,
            )
            .then((result) => result.getOrElse((error) => throw error));

        parseData =
            await _parseAndExtract(
              bookPath,
              fileHash,
              originalFileName ?? file.path.split('/').last,
            ).then((result) async {
              if (result.isLeft()) {
                // 解析失败由文件作用域恢复导入前状态。
                throw result.getLeft().toNullable()!;
              }
              return result.getRight().toNullable()!;
            });

        coverPath = await _coverExtractor.extract(
          epubPath: bookPath,
          fileHash: fileHash,
          coverHref: parseData.coverHref,
          opfRootPath: parseData.opfRootPath,
          changes: files,
        );
      }

      final entities = await _createEntities(
        fileHash,
        bookPath,
        coverPath,
        parseData,
        bookExists.getRight().toNullable()!,
      );

      final savedBook = await _saveWithManifest(entities.$1, entities.$2).then((
        result,
      ) async {
        if (result.isLeft()) {
          // 数据库与文件分别回滚各自的变更。
          throw result.getLeft().toNullable()!;
        }
        return result.getRight().toNullable()!;
      });

      files.commit();
      return right(savedBook);
    } on LibraryException catch (e) {
      return left(e);
    } catch (e) {
      return left(LibraryException(LibraryErrorCode.importFailed, e));
    } finally {
      await files.close();
    }
  }

  /// Check if book already exists
  /// Returns Either:
  ///   - Left: error (book already exists)
  ///   - Right: true if book exists but deleted, false if never existed
  Future<Either<LibraryException, bool>> _checkBookExistence(
    String fileHash,
  ) async {
    final existsAndNotDeleted = await _shelfBookRepo.bookExistsAndNotDeleted(
      fileHash,
    );
    if (existsAndNotDeleted) {
      return left(LibraryException(LibraryErrorCode.duplicateBook, fileHash));
    }

    final exists = await _shelfBookRepo.bookExists(fileHash);
    return right(exists);
  }

  /// Parse EPUB and extract metadata using isolate
  Future<Either<LibraryException, EpubZipParseResult>> _parseAndExtract(
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
    EpubZipParseResult parseData,
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

  /// 在同一事务中保存 ShelfBook 与 BookManifest（见 [LibraryBookStore]）。
  /// 失败时数据库已由事务回滚，返回 Left 交给调用方清理已落盘的文件。
  Future<Either<LibraryException, ShelfBook>> _saveWithManifest(
    ShelfBook shelfBook,
    BookManifest manifest,
  ) async {
    final result = await _libraryBookStore.saveBookWithManifest(
      shelfBook,
      manifest,
    );
    return result
        .map((bookId) => shelfBook.copyWith(id: bookId))
        .mapLeft(
          (error) => LibraryException(LibraryErrorCode.saveFailed, error),
        );
  }
}
