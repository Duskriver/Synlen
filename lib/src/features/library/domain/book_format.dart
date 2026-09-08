/// 书籍文件格式。
///
/// Synlen 当前支持 EPUB 与 TXT；新格式在此扩展，
/// 并在 `BookImportService` 的解析分发与原生选择器过滤中同步放开。
enum BookFormat {
  epub,
  txt;

  /// 从文件名（或完整路径）识别格式；无法识别时回退为 EPUB。
  static BookFormat fromFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.txt')) {
      return BookFormat.txt;
    }
    return BookFormat.epub;
  }

  /// 该格式书籍在 `books/` 目录中存储时使用的扩展名（含点）。
  String get fileExtension => switch (this) {
    BookFormat.epub => '.epub',
    BookFormat.txt => '.txt',
  };
}
