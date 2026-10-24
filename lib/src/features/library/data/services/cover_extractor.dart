import 'dart:io';

import 'book_file_changes.dart';

import 'package:flutter/foundation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import 'epub_cover_reader.dart';
import 'epub_import_workers.dart';

/// EPUB 封面提取：按 OPF 根目录解析封面条目，压缩后写入 covers 目录。
///
/// 提取失败不影响导入主流程，只记日志并返回 null。
class CoverExtractor {
  const CoverExtractor();

  /// 返回已落盘封面的相对路径；封面缺失或提取失败时返回 null。
  Future<String?> extract({
    required String epubPath,
    required String fileHash,
    required String? coverHref,
    required String opfRootPath,
    BookFileChanges? changes,
  }) async {
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

      final opfDir = opfRootPath.contains('/')
          ? opfRootPath.substring(0, opfRootPath.lastIndexOf('/'))
          : '';
      final coverPath = opfDir.isEmpty ? coverHref : '$opfDir/$coverHref';

      var extension = _getImageExtension(coverPath);

      final rawCoverData = await compute(readEpubCover, (
        epubPath: epubPath,
        coverPath: coverPath,
      ));
      if (rawCoverData == null || rawCoverData.isEmpty) {
        return null;
      }

      var coverData = await ImportWorkers.compressImage(rawCoverData);
      if (coverData != null) {
        extension = '.jpg';
      } else {
        coverData = rawCoverData;
      }

      final outputPath = '${coversDir.path}/$fileHash$extension';
      if (changes != null) {
        await changes.write(File(outputPath), coverData as List<int>);
      } else {
        await File(outputPath).writeAsBytes(coverData as List<int>);
      }

      return '${AppStorageConstants.coversDir}/$fileHash$extension';
    } catch (e) {
      // 封面提取失败不影响主流程，仅记录日志
      appLogger.w('Cover extraction failed: $e');
      return null;
    }
  }

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
    return specifiedExtension ?? '.jpg';
  }
}
