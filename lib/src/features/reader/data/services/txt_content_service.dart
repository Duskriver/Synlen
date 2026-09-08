import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/txt_chapter_path.dart';
import 'package:synlen/src/features/library/domain/txt_heading.dart';

import 'txt_spine_source.dart';

/// TXT 章节内容供给服务。
///
/// TXT 书籍以归一化 UTF-8 单文件存盘，阅读时按 manifest spine 中记录的
/// 字节范围（[SpineItem.sourceRange]）随机读取，包装为 XHTML 后经
/// `epub://` 虚拟域交给渲染引擎——对前端分页引擎而言与 EPUB 章节无异。
class TxtContentService {
  final TxtSpineSource _spineSource;

  /// fileHash → spine 的会话级缓存，避免每次翻章都查库
  final Map<String, List<SpineItem>> _spineCache = {};

  TxtContentService({required TxtSpineSource spineSource})
    : _spineSource = spineSource;

  /// 读取指定虚拟路径（`txt/chapter_N.xhtml`）的章节 XHTML。
  /// Returns Either:
  ///   - Left: error message
  ///   - Right: (XHTML bytes, mimeType)
  Future<Either<String, (Uint8List, String)>> readChapter({
    required String txtAbsolutePath,
    required String fileHash,
    required String relativePath,
  }) async {
    final chapterIndex = txtChapterIndexFromPath(relativePath);
    if (chapterIndex == null) {
      return left('Not a TXT chapter path: $relativePath');
    }

    final spine = await _spineFor(fileHash);
    if (spine == null) {
      return left('Manifest not found for book: $fileHash');
    }
    if (chapterIndex < 0 || chapterIndex >= spine.length) {
      return left('Chapter index out of range: $chapterIndex');
    }

    final range = _parseByteRange(spine[chapterIndex].sourceRange);
    if (range == null) {
      return left('Missing byte range for chapter $chapterIndex');
    }

    final sliceBytes = await _readRange(txtAbsolutePath, range.$1, range.$2);
    if (sliceBytes == null) {
      return left('Failed to read TXT file: $txtAbsolutePath');
    }

    final chapterText = utf8DecodeLossy(sliceBytes);
    final html = buildChapterHtml(chapterText);
    return right((utf8EncodeToBytes(html), 'application/xhtml+xml'));
  }

  /// 章节文本 → XHTML。首个非空行若为标题行则渲染为 <h2>，
  /// 其余非空行渲染为 <p>；空行折叠。内容一律转义。
  static String buildChapterHtml(String text) {
    final buffer = StringBuffer()
      // xmlns 不可省：章节以 application/xhtml+xml 提供，按 XML 解析时
      // 无命名空间的元素不具备 HTML 语义（<p> 退化为内联、document.head
      // 为 null），渲染引擎注入样式时会抛 TypeError
      ..write(
        '<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml"><head><meta charset="utf-8" />',
      )
      ..write('<meta name="generator" content="synlen" /></head><body>');

    var isFirstContentLine = true;
    for (final rawLine in text.split(RegExp(r'\r\n|\r|\n'))) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;
      final escaped = _escapeHtml(trimmed);
      if (isFirstContentLine && isTxtHeadingLine(rawLine)) {
        buffer.write('<h2>$escaped</h2>');
      } else {
        buffer.write('<p>$escaped</p>');
      }
      isFirstContentLine = false;
    }

    buffer.write('</body></html>');
    return buffer.toString();
  }

  static String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<List<SpineItem>?> _spineFor(String fileHash) async {
    final cached = _spineCache[fileHash];
    if (cached != null) return cached;

    final spine = await _spineSource.spineFor(fileHash);
    if (spine != null) {
      _spineCache[fileHash] = spine;
    }
    return spine;
  }

  /// 解析 "start-end" 形式的字节范围
  static (int, int)? _parseByteRange(String? sourceRange) {
    if (sourceRange == null) return null;
    final parts = sourceRange.split('-');
    if (parts.length != 2) return null;
    final start = int.tryParse(parts[0]);
    final end = int.tryParse(parts[1]);
    if (start == null || end == null || start < 0 || end < start) return null;
    return (start, end);
  }

  /// 随机读取文件的 [start, end) 字节区间
  static Future<Uint8List?> _readRange(String path, int start, int end) async {
    RandomAccessFile? raf;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      raf = await file.open();
      final length = await raf.length();
      final safeEnd = end > length ? length : end;
      await raf.setPosition(start);
      return await raf.read(safeEnd - start);
    } catch (_) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  /// 有损 UTF-8 解码（归一化文件理论上总是合法 UTF-8，此处仅防御）
  static String utf8DecodeLossy(Uint8List bytes) =>
      const Utf8Decoder(allowMalformed: true).convert(bytes);

  static Uint8List utf8EncodeToBytes(String text) =>
      Uint8List.fromList(utf8.encode(text));

  void dispose() {
    _spineCache.clear();
  }
}
