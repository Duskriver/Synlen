import '../../domain/txt_heading.dart';

/// TXT 章节切分结果：一个章节的标题与在全文中的字符区间。
///
/// 所有章节的 [start, end) 区间连续覆盖全文 [0, length)，
/// 保证归一化字节流与章节切片的字节范围严格对齐。
class TxtChapter {
  /// 章节标题（TOC 展示用；[hasHeading] 为 true 时即标题行原文）
  final String title;

  /// 章节内容在全文字符串中的起始偏移（含）
  final int start;

  /// 章节内容在全文字符串中的结束偏移（不含）
  final int end;

  /// 是否由标题行切分产生；false 表示引导块或按体积分割的部分
  final bool hasHeading;

  /// 是否为"卷"级标题（仅影响 TOC 层级，不影响内容切片）
  final bool isVolume;

  const TxtChapter({
    required this.title,
    required this.start,
    required this.end,
    required this.hasHeading,
    this.isVolume = false,
  });
}

/// TXT 章节切分器。
///
/// 策略：
/// 1. 扫描独立标题行（第X章/回/节/集/部/篇、第X卷、Chapter N、
///    楔子/序言/后记等特殊行、纯数字行），标题行即新章节起点；
/// 2. 首个标题之前的非空内容归为引导块章节，纯空白并入第一章；
/// 3. 全文找不到任何标题行时，超过 [_splitThreshold] 的正文按段落
///    边界切分为固定大小的"部分"，避免单页 HTML 过大。
class TxtChapterSplitter {
  const TxtChapterSplitter();

  /// 无标题正文触发按体积分割的字符数阈值
  static const int splitThreshold = 50000;

  /// 按体积分割时的目标单部分字符数（在段落边界就近截断）
  static const int targetPartLength = 50000;

  List<TxtChapter> split(String text) {
    if (text.trim().isEmpty) return const [];

    final lineStarts = _lineStarts(text);
    final headingLines = <int>[
      for (var i = 0; i < lineStarts.length; i++)
        if (isTxtHeadingLine(_lineAt(text, lineStarts, i))) i,
    ];

    if (headingLines.isEmpty) {
      return _splitBySize(text);
    }

    final chapters = <TxtChapter>[];

    // 首个标题行之前的引导块（非空才独立成章）
    final firstHeadingOffset = lineStarts[headingLines.first];
    if (text.substring(0, firstHeadingOffset).trim().isNotEmpty) {
      chapters.add(
        TxtChapter(
          title: _firstLineTitle(text.substring(0, firstHeadingOffset)),
          start: 0,
          end: firstHeadingOffset,
          hasHeading: false,
        ),
      );
    }

    for (var h = 0; h < headingLines.length; h++) {
      final lineIndex = headingLines[h];
      final start = h == 0 && chapters.isEmpty ? 0 : lineStarts[lineIndex];
      final end = h + 1 < headingLines.length
          ? lineStarts[headingLines[h + 1]]
          : text.length;
      final line = _lineAt(text, lineStarts, lineIndex);
      chapters.add(
        TxtChapter(
          title: line.trim(),
          start: start,
          end: end,
          hasHeading: true,
          isVolume: isTxtVolumeHeading(line),
        ),
      );
    }

    return chapters;
  }

  /// 返回每一行的起始字符偏移（兼容 \n、\r\n、\r）
  static List<int> _lineStarts(String text) {
    final starts = <int>[0];
    for (var i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 0x0A) {
        // \n
        starts.add(i + 1);
      } else if (code == 0x0D) {
        // \r 或 \r\n
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) {
          i++;
        }
        starts.add(i + 1);
      }
    }
    return starts;
  }

  /// 取第 [index] 行内容（不含行尾换行符）
  static String _lineAt(String text, List<int> starts, int index) {
    final start = starts[index];
    final end = index + 1 < starts.length ? starts[index + 1] : text.length;
    var line = text.substring(start, end);
    while (line.isNotEmpty &&
        (line.codeUnitAt(line.length - 1) == 0x0A ||
            line.codeUnitAt(line.length - 1) == 0x0D)) {
      line = line.substring(0, line.length - 1);
    }
    return line;
  }

  /// 引导块标题：取首个非空行（截断至 30 字符），无则叫"正文"
  static String _firstLineTitle(String text) {
    for (final line in text.split(RegExp(r'\r\n|\r|\n'))) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        return trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
      }
    }
    return '正文';
  }

  /// 无标题时按体积分割：在目标长度附近的最后一个空行处截断
  static List<TxtChapter> _splitBySize(String text) {
    if (text.length <= splitThreshold) {
      return [
        TxtChapter(
          title: _firstLineTitle(text),
          start: 0,
          end: text.length,
          hasHeading: false,
        ),
      ];
    }

    final chapters = <TxtChapter>[];
    var start = 0;
    var partIndex = 1;
    while (start < text.length) {
      var end = start + targetPartLength;
      if (end >= text.length) {
        end = text.length;
      } else {
        // 从目标位置向前找最近的空行，避免把段落拦腰截断
        final paragraphBreak = text.lastIndexOf(RegExp(r'\n\s*\n'), end);
        if (paragraphBreak > start + targetPartLength ~/ 2) {
          end = paragraphBreak;
        }
      }
      // UTF-16 的代理对不能分到不同章节，否则分别编码 UTF-8 会损坏字符。
      if (end < text.length &&
          end > start &&
          text.codeUnitAt(end - 1) >= 0xD800 &&
          text.codeUnitAt(end - 1) <= 0xDBFF &&
          text.codeUnitAt(end) >= 0xDC00 &&
          text.codeUnitAt(end) <= 0xDFFF) {
        end++;
      }
      chapters.add(
        TxtChapter(
          title: '第 $partIndex 部分',
          start: start,
          end: end,
          hasHeading: false,
        ),
      );
      start = end;
      partIndex++;
    }
    return chapters;
  }
}
