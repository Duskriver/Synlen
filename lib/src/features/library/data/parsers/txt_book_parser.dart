import 'dart:convert';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import '../../domain/book_manifest.dart';
import 'txt_chapter_splitter.dart';
import 'txt_decoder.dart';

/// TXT 书籍解析结果
class TxtBookParseResult {
  /// 书名（取文件名去掉扩展名）
  final String title;

  /// 线性阅读顺序：每章一项，href 为虚拟文件路径 `txt/chapter_N.xhtml`，
  /// [SpineItem.sourceRange] 记录章节在归一化 UTF-8 字节流中的范围
  final List<SpineItem> spine;

  /// 目录（卷为父节点，章为子节点；无卷时全部平铺）
  final List<TocItem> toc;

  /// 归一化后的全文 UTF-8 字节（导入时以此替换原文件存储，
  /// 使阅读时无需关心原始编码）
  final Uint8List normalizedUtf8;

  final int totalChapters;

  const TxtBookParseResult({
    required this.title,
    required this.spine,
    required this.toc,
    required this.normalizedUtf8,
    required this.totalChapters,
  });
}

/// TXT 书籍解析器：解码 → 章节切分 → 归一化 UTF-8 → 生成 spine/TOC。
///
/// 纯内存纯 Dart，无文件/数据库依赖，可直接在 isolate 中运行。
class TxtBookParser {
  const TxtBookParser();

  static const _decoder = TxtDecoder();
  static const _splitter = TxtChapterSplitter();

  /// 阅读时 WebView 请求的虚拟章节路径前缀
  static const String chapterPathPrefix = 'txt/chapter_';

  static const String chapterPathSuffix = '.xhtml';

  /// 从虚拟章节路径解析 spine 索引，路径非法时返回 null
  static int? chapterIndexFromPath(String relativePath) {
    final match = RegExp(
      '^${RegExp.escape(chapterPathPrefix)}(\\d+)${RegExp.escape(chapterPathSuffix)}\$',
    ).firstMatch(relativePath);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  Either<String, TxtBookParseResult> parseFromBytes(
    Uint8List bytes, {
    String? fileName,
  }) {
    try {
      final decoded = _decoder.decode(bytes);
      return parseFromText(decoded.text, fileName: fileName);
    } catch (e) {
      return left('TXT decode error: $e');
    }
  }

  /// 对已解码文本执行切分与 manifest 生成（与字节入口共享逻辑，便于测试）
  Either<String, TxtBookParseResult> parseFromText(
    String text, {
    String? fileName,
  }) {
    try {
      final chapters = _splitter.split(text);
      if (chapters.isEmpty) {
        return left('TXT 文件为空');
      }

      // 归一化为 UTF-8，并按章节切片累加字节长度得到各章节的字节范围
      final normalizedUtf8 = utf8.encode(text);
      final spine = <SpineItem>[];
      var byteOffset = 0;
      for (var i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final sliceBytes = utf8.encode(
          text.substring(chapter.start, chapter.end),
        );
        spine.add(
          SpineItem(
            index: i,
            href: '$chapterPathPrefix$i$chapterPathSuffix',
            idref: 'txt-chapter-$i',
            linear: true,
            sourceRange: '$byteOffset-${byteOffset + sliceBytes.length}',
          ),
        );
        byteOffset += sliceBytes.length;
      }

      final toc = _buildToc(chapters);

      return right(
        TxtBookParseResult(
          title: _titleFromFileName(fileName),
          spine: spine,
          toc: toc,
          normalizedUtf8: Uint8List.fromList(normalizedUtf8),
          totalChapters: chapters.length,
        ),
      );
    } catch (e) {
      return left('TXT parse error: $e');
    }
  }

  /// 构建 TOC：卷级标题为父节点，其后的章节挂为子节点。
  /// id 按深度优先顺序分配（与 [BookSession] 运行时展平顺序一致），
  /// 保证 parentId 引用稳定。
  static List<TocItem> _buildToc(List<TxtChapter> chapters) {
    final toc = <TocItem>[];
    TocItem? currentVolume;
    var nextId = 0;

    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final href = Href(
        path: '$chapterPathPrefix$i$chapterPathSuffix',
        anchor: 'top',
      );

      if (chapter.isVolume) {
        currentVolume = TocItem(
          id: nextId++,
          label: chapter.title,
          href: href,
          depth: 0,
          spineIndex: i,
        );
        toc.add(currentVolume);
      } else {
        final item = TocItem(
          id: nextId++,
          label: chapter.title,
          href: href,
          depth: currentVolume == null ? 0 : 1,
          spineIndex: i,
          parentId: currentVolume?.id ?? -1,
        );
        if (currentVolume == null) {
          toc.add(item);
        } else {
          currentVolume.children.add(item);
        }
      }
    }

    return toc;
  }

  static String _titleFromFileName(String? fileName) {
    if (fileName == null || fileName.isEmpty) {
      return 'Unknown Title';
    }
    final base = fileName.split('/').last.split('\\').last;
    final dotIndex = base.lastIndexOf('.');
    final stem = dotIndex > 0 ? base.substring(0, dotIndex) : base;
    return stem.isEmpty ? 'Unknown Title' : stem;
  }
}
