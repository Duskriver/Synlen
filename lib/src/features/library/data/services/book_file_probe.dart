import 'dart:io';

import 'package:synlen/src/features/library/domain/book_format.dart';

/// 导入前的文件探测：格式识别。
class BookFileProbe {
  const BookFileProbe();

  /// 识别书籍格式。
  ///
  /// 优先按扩展名；扩展名为 .epub 时用 ZIP 魔数嗅探纠偏——
  /// Android 系统分享进来的 content:// URI 可能取不到真实文件名
  /// （[AndroidUriPath.name] 兜底为 unknown.epub），TXT 若被误判为
  /// EPUB 会直接解析失败，而 EPUB 本质是 ZIP 容器，嗅探可靠。
  Future<BookFormat> detectFormat(File file, String? originalFileName) async {
    final byName = BookFormat.fromFileName(originalFileName ?? file.path);
    if (byName == BookFormat.txt) return BookFormat.txt;
    if (await _looksLikeZip(file)) return BookFormat.epub;
    return BookFormat.txt;
  }

  /// ZIP 容器魔数检查（"PK"）
  Future<bool> _looksLikeZip(File file) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final bytes = await raf.read(2);
      return bytes.length == 2 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    } catch (_) {
      return false;
    } finally {
      await raf?.close();
    }
  }
}
