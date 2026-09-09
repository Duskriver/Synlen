import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

void main() {
  test('mimeType 按格式区分：TXT 不再被标成 EPUB', () {
    expect(BookFormat.epub.mimeType, 'application/epub+zip');
    expect(BookFormat.txt.mimeType, 'text/plain');
  });

  test('fromFileName 识别扩展名，未知格式回退 EPUB', () {
    expect(BookFormat.fromFileName('a.txt'), BookFormat.txt);
    expect(BookFormat.fromFileName('A.TXT'), BookFormat.txt);
    expect(BookFormat.fromFileName('a.epub'), BookFormat.epub);
    expect(BookFormat.fromFileName('a.mobi'), BookFormat.epub);
  });

  test('fileExtension 与 fromFileName 互为逆运算', () {
    for (final format in BookFormat.values) {
      expect(BookFormat.fromFileName('book${format.fileExtension}'), format);
    }
  });
}
