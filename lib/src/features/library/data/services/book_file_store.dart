import 'dart:io';
import 'book_file_changes.dart';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import '../../domain/book_format.dart';
import '../../domain/library_exception.dart';

/// 书籍文件落盘：EPUB 原样复制，TXT 写归一化字节。
class BookFileStore {
  const BookFileStore();

  /// Copy EPUB file to books directory
  /// Returns absolute path to the copied file
  Future<Either<LibraryException, String>> copyBook(
    File sourceFile,
    String fileHash, {
    bool moveSourceFile = false,
    BookFileChanges? changes,
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

      if (changes != null) {
        await changes.copyIfMissing(
          sourceFile,
          targetFile,
          moveSource: moveSourceFile,
        );
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
      return left(LibraryException(LibraryErrorCode.fileWriteFailed, e));
    }
  }

  /// Write normalized UTF-8 TXT content to books directory
  ///
  /// 与 EPUB 的直接拷贝不同：TXT 在解析时已归一化为 UTF-8，
  /// 此处落盘的是归一化结果而非源文件，阅读时无需关心原始编码。
  /// Returns absolute path to the written file
  Future<Either<LibraryException, String>> writeNormalizedTxt(
    Uint8List normalizedBytes,
    String fileHash, {
    BookFileChanges? changes,
  }) async {
    try {
      final booksDir = Directory(
        '${AppStorage.documentsPath}${AppStorageConstants.booksDir}',
      );
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final targetPath =
          '${booksDir.path}/$fileHash${BookFormat.txt.fileExtension}';
      if (changes != null) {
        await changes.write(File(targetPath), normalizedBytes);
      } else {
        await File(targetPath).writeAsBytes(normalizedBytes, flush: true);
      }
      return right(targetPath);
    } catch (e) {
      return left(LibraryException(LibraryErrorCode.fileWriteFailed, e));
    }
  }

  /// 逻辑删除提交后清理原书与封面；失败交由 application 保留待清理状态。
  Future<void> removeFiles(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(
        path.startsWith('/') ? path : '${AppStorage.documentsPath}$path',
      );
      if (await file.exists()) await file.delete();
    }
  }
}
