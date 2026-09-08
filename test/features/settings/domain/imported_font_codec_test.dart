import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/settings/domain/imported_font.dart';
import 'package:synlen/src/features/settings/domain/imported_font_codec.dart';

void main() {
  test('null 与空串解码为空列表', () {
    expect(decodeImportedFonts(null), isEmpty);
    expect(decodeImportedFonts(''), isEmpty);
  });

  test('非法 JSON 解码为空列表', () {
    expect(decodeImportedFonts('not json'), isEmpty);
    expect(decodeImportedFonts('{"a":1}'), isEmpty);
  });

  test('跳过非字符串条目', () {
    final fonts = decodeImportedFonts('["MyFont.ttf", 42, null, "Other.otf"]');

    expect(fonts.map((f) => f.fileName), ['MyFont.ttf', 'Other.otf']);
  });

  test('编码只写文件名数组', () {
    final json = encodeImportedFonts(const [
      ImportedFont(fileName: 'MyFont.ttf'),
      ImportedFont(fileName: 'Other.otf'),
    ]);

    expect(json, '["MyFont.ttf","Other.otf"]');
  });

  test('编解码往返保持列表', () {
    const fonts = [
      ImportedFont(fileName: 'MyFont.ttf'),
      ImportedFont(fileName: 'Other.otf'),
    ];

    expect(decodeImportedFonts(encodeImportedFonts(fonts)), fonts);
  });
}
