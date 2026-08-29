import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fpdart/fpdart.dart';
import '../../domain/book_format.dart';
import '../../domain/book_manifest.dart';
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

/// Result of in-memory EPUB parsing
class ParseResult {
  final String title;
  final String author;
  final List<String> authors;
  final String? description;
  final List<String> subjects;
  final String? coverHref;
  final String opfRootPath;
  final String epubVersion;
  final int totalChapters;
  final List<SpineItem> spine;
  final List<TocItem> toc;
  final List<ManifestItem> manifestItems;
  final int readDirection;

  /// 书籍格式（EPUB/TXT），决定存储扩展名与阅读时的内容供给方式
  final BookFormat format;

  ParseResult({
    required this.title,
    required this.author,
    required this.authors,
    this.description,
    required this.subjects,
    this.coverHref,
    required this.opfRootPath,
    required this.epubVersion,
    required this.totalChapters,
    required this.spine,
    required this.toc,
    required this.manifestItems,
    required this.readDirection,
    this.format = BookFormat.epub,
  });
}

/// TXT 解析产物：统一 ParseResult + 归一化 UTF-8 字节流
class TxtParseOutcome {
  final ParseResult parseResult;
  final Uint8List normalizedBytes;

  TxtParseOutcome({required this.parseResult, required this.normalizedBytes});
}

/// Static utility class for EPUB import operations
/// These methods are designed to be run in isolates via compute()
class ImportWorkers {
  /// Calculate SHA-256 hash of a file and convert to Base62
  static Future<Either<String, String>> calculateFileHash(String path) async {
    try {
      final file = File(path);
      final stream = file.openRead();
      final digest = await sha256.bind(stream).first;

      BigInt number = BigInt.parse(digest.toString(), radix: 16);
      final hash = _toBase62(number);

      return right(hash);
    } catch (e) {
      return left('Hash calculation failed: $e');
    }
  }

  /// Parse EPUB file in-memory and extract metadata
  static Future<Either<String, ParseResult>> parseEpub(
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

      final data = parseResult.getRight().toNullable()!;

      final result = ParseResult(
        title: data.title,
        author: data.author,
        authors: data.authors,
        description: data.description,
        subjects: data.subjects,
        coverHref: data.coverHref,
        opfRootPath: data.opfRootPath,
        epubVersion: data.epubVersion,
        totalChapters: data.totalChapters,
        spine: data.spine,
        toc: data.toc,
        manifestItems: data.manifestItems,
        readDirection: data.readDirection,
      );

      return right(result);
    } catch (e) {
      return left('Parse error: $e');
    }
  }

  /// Parse TXT file in-memory: decode → split chapters → normalize to UTF-8
  static Future<Either<String, TxtParseOutcome>> parseTxt(
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

      return right(
        TxtParseOutcome(
          parseResult: ParseResult(
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
      return left('Parse error: $e');
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

  /// Convert BigInt to Base62 string
  static String _toBase62(BigInt num) {
    if (num == BigInt.zero) return '0';

    const chars =
        '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final base = BigInt.from(chars.length);
    final codeUnits = <int>[];

    while (num > BigInt.zero) {
      var remainder = (num % base).toInt();
      codeUnits.add(chars.codeUnitAt(remainder));
      num = num ~/ base;
    }

    return String.fromCharCodes(codeUnits.reversed);
  }
}
