import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import '../../domain/book_format.dart';

/// 书籍文件落盘：EPUB 原样复制，TXT 写归一化字节。
class BookFileStore {
  const BookFileStore();

  /// Copy EPUB file to books directory
  /// Returns absolute path to the copied file
  Future<Either<String, String>> copyBook(
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

  /// Write normalized UTF-8 TXT content to books directory
  ///
  /// 与 EPUB 的直接拷贝不同：TXT 在解析时已归一化为 UTF-8，
  /// 此处落盘的是归一化结果而非源文件，阅读时无需关心原始编码。
  /// Returns absolute path to the written file
  Future<Either<String, String>> writeNormalizedTxt(
    Uint8List normalizedBytes,
    String fileHash,
  ) async {
    try {
      final booksDir = Directory(
        '${AppStorage.documentsPath}${AppStorageConstants.booksDir}',
      );
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final targetPath =
          '${booksDir.path}/$fileHash${BookFormat.txt.fileExtension}';
      await File(targetPath).writeAsBytes(normalizedBytes, flush: true);
      return right(targetPath);
    } catch (e) {
      return left('File write failed: $e');
    }
  }
}
