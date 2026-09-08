import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/file_handling/backup_paths.dart';
import 'package:synlen/src/core/file_handling/platform_path.dart';

void main() {
  BackupEntry entry(String displayPath) =>
      (displayPath: displayPath, platformPath: IOSFilePath(displayPath));

  group('classifyBackupEntries', () {
    test('识别书架文件与三类书籍组件', () {
      final result = classifyBackupEntries([
        entry('/backup/shelf.json'),
        entry('/backup/books/abc.epub'),
        entry('/backup/manifests/abc.json'),
        entry('/backup/covers/abc.png'),
        entry('/backup/books/def.txt'),
        entry('/backup/manifests/def.json'),
      ]);

      expect(result.shelfFile, isA<IOSFilePath>());
      expect(result.tempBookComponents.keys, containsAll(['abc', 'def']));
      expect(result.tempBookComponents['abc']!['epub'], isNotNull);
      expect(result.tempBookComponents['abc']!['manifest'], isNotNull);
      expect(result.tempBookComponents['abc']!['cover'], isNotNull);
      expect(result.tempBookComponents['def']!['cover'], isNull);
    });

    test('忽略无关目录与非法条目', () {
      final result = classifyBackupEntries([
        entry('/backup/fonts/a.ttf'),
        entry('/backup/books/README'),
        entry(''),
      ]);

      expect(result.shelfFile, isNull);
      expect(result.tempBookComponents, isEmpty);
    });
  });

  group('buildBackupBookPaths', () {
    test('书文件与清单齐备时装配，缺一则跳过', () {
      final result = buildBackupBookPaths({
        'a': {
          'epub': IOSFilePath('/b/a.epub'),
          'manifest': IOSFilePath('/b/a.json'),
          'cover': IOSFilePath('/b/a.png'),
        },
        'b': {'epub': IOSFilePath('/b/b.epub')},
      });

      expect(result.keys, ['a']);
      expect(result['a']!.coverPath, isNotNull);
    });

    test('无封面时 coverPath 为空', () {
      final result = buildBackupBookPaths({
        'a': {
          'epub': IOSFilePath('/b/a.epub'),
          'manifest': IOSFilePath('/b/a.json'),
        },
      });

      expect(result['a']!.coverPath, isNull);
    });
  });
}
