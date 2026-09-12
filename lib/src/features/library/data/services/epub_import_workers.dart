import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fpdart/fpdart.dart';
import '../../domain/book_format.dart';
import '../../domain/library_exception.dart';
import '../parsers/epub_zip_parser.dart';
import '../parsers/txt_book_parser.dart';

/// Configuration constants for import workers
class ImportWorkerConfig {
  static const int imageThumbnailMaxHeight = 1200;
  static const int imageCompressionQuality = 90;
}

/// Parameters for isolate parsing
class ParseParams {
  final String filePath;
  final String fileHash;
  final String? originalFileName;

  ParseParams({
    required this.filePath,
    required this.fileHash,
    this.originalFileName,
  });
}

/// TXT 解析产物：统一解析结果 + 归一化 UTF-8 字节流
class TxtParseOutcome {
  final EpubZipParseResult parseResult;
  final Uint8List normalizedBytes;

  TxtParseOutcome({required this.parseResult, required this.normalizedBytes});
}

/// Static utility class for EPUB import operations
/// These methods are designed to be run in isolates via compute()
class ImportWorkers {
  /// Parse EPUB file in-memory and extract metadata
  static Future<Either<LibraryException, EpubZipParseResult>> parseEpub(
    ParseParams params,
  ) async {
    try {
      final parser = EpubZipParser();
      final parseResult = await parser.parseFromFile(
        params.filePath,
        fileName: params.originalFileName,
      );

      if (parseResult.isLeft()) {
        return left(parseResult.getLeft().toNullable()!);
      }

      return right(parseResult.getRight().toNullable()!);
    } catch (e) {
      return left(LibraryException(LibraryErrorCode.parseFailed, e));
    }
  }

  /// Parse TXT file in-memory: decode → split chapters → normalize to UTF-8
  static Future<Either<LibraryException, TxtParseOutcome>> parseTxt(
    ParseParams params,
  ) async {
    try {
      final bytes = await File(params.filePath).readAsBytes();
      final result = const TxtBookParser().parseFromBytes(
        bytes,
        fileName: params.originalFileName,
      );

      if (result.isLeft()) {
        return left(result.getLeft().toNullable()!);
      }

      final data = result.getRight().toNullable()!;

      // TXT 无 EPUB 专属信息，空串 / null / 空列表字段原样落库
      // （与合并前 ParseResult 的填法一字节相同）
      return right(
        TxtParseOutcome(
          parseResult: EpubZipParseResult(
            title: data.title,
            author: '',
            authors: const [],
            subjects: const [],
            coverHref: null,
            opfRootPath: '',
            epubVersion: '',
            totalChapters: data.totalChapters,
            spine: data.spine,
            toc: data.toc,
            manifestItems: const [],
            readDirection: 0,
            format: BookFormat.txt,
          ),
          normalizedBytes: data.normalizedUtf8,
        ),
      );
    } catch (e) {
      return left(LibraryException(LibraryErrorCode.parseFailed, e));
    }
  }

  /// Compress and resize image to JPEG format
  /// Returns null if image cannot be compressed
  static Future<Uint8List?> compressImage(
    Uint8List rawBytes, {
    int maxHeight = ImportWorkerConfig.imageThumbnailMaxHeight,
    int quality = ImportWorkerConfig.imageCompressionQuality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        rawBytes,
        // For cover images, we prioritize height to maintain aspect ratio and avoid excessive width
        minWidth: maxHeight,
        minHeight: maxHeight,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return result.isEmpty ? null : result;
    } catch (e) {
      appLogger.w('Image compression worker error: $e');
      return null;
    }
  }
}
