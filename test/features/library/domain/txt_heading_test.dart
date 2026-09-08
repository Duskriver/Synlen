import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/txt_heading.dart';

void main() {
  group('isTxtHeadingLine', () {
    test('识别中文章节标题', () {
      expect(isTxtHeadingLine('第一章 开始'), isTrue);
      expect(isTxtHeadingLine('第1章'), isTrue);
      expect(isTxtHeadingLine('第十二章：转折'), isTrue);
      expect(isTxtHeadingLine('  第三回   '), isTrue);
      expect(isTxtHeadingLine('第１２章 全角数字'), isTrue);
    });

    test('识别卷 / 英文 / 特殊 / 纯数字标题', () {
      expect(isTxtHeadingLine('第一卷 风起'), isTrue);
      expect(isTxtHeadingLine('chapter 3'), isTrue);
      expect(isTxtHeadingLine('Chapter 12: The End'), isTrue);
      expect(isTxtHeadingLine('楔子'), isTrue);
      expect(isTxtHeadingLine('番外：日常'), isTrue);
      expect(isTxtHeadingLine('42'), isTrue);
    });

    test('拒绝正文与非法标题', () {
      expect(isTxtHeadingLine('这是一段正文，不是标题。'), isFalse);
      expect(isTxtHeadingLine(''), isFalse);
      expect(isTxtHeadingLine('12345'), isFalse); // 纯数字限 1~4 位
      // 超长行不视为标题（防正文误判）
      expect(isTxtHeadingLine('第一章 ${'长' * 60}'), isFalse);
    });
  });

  group('isTxtVolumeHeading', () {
    test('只有卷级标题为真', () {
      expect(isTxtVolumeHeading('第一卷 风起'), isTrue);
      expect(isTxtVolumeHeading('第一章 开始'), isFalse);
      expect(isTxtVolumeHeading('正文'), isFalse);
    });
  });
}
