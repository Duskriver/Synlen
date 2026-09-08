import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/txt_chapter_path.dart';

void main() {
  group('txtChapterIndexFromPath', () {
    test('解析合法虚拟章节路径', () {
      expect(txtChapterIndexFromPath('txt/chapter_0.xhtml'), 0);
      expect(txtChapterIndexFromPath('txt/chapter_12.xhtml'), 12);
    });

    test('拒绝非法路径', () {
      expect(txtChapterIndexFromPath('txt/chapter_x.xhtml'), isNull);
      expect(txtChapterIndexFromPath('txt/chapter_1.txt'), isNull);
      expect(txtChapterIndexFromPath('other/chapter_1.xhtml'), isNull);
      expect(txtChapterIndexFromPath('txt/chapter_1.xhtml/extra'), isNull);
    });
  });
}
