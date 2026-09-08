import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/settings/domain/imported_font.dart';

void main() {
  group('ImportedFont.displayName', () {
    test('去掉扩展名', () {
      expect(const ImportedFont(fileName: 'MyFont.ttf').displayName, 'MyFont');
    });

    test('多点文件名只去掉最后一段', () {
      expect(
        const ImportedFont(fileName: 'My.Font.v2.otf').displayName,
        'My.Font.v2',
      );
    });

    test('无扩展名时原样返回', () {
      expect(const ImportedFont(fileName: 'MyFont').displayName, 'MyFont');
    });

    test('以点开头的隐藏文件不截断为空', () {
      expect(const ImportedFont(fileName: '.hidden').displayName, '.hidden');
    });
  });

  test('相同文件名视为相等', () {
    expect(
      const ImportedFont(fileName: 'a.ttf'),
      const ImportedFont(fileName: 'a.ttf'),
    );
    expect(
      const ImportedFont(fileName: 'a.ttf'),
      isNot(const ImportedFont(fileName: 'b.ttf')),
    );
  });
}
