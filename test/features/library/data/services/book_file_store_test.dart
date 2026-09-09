import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';

void main() {
  const store = BookFileStore();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen_file_store_test_');
    AppStorage.initForTesting(
      documentsPath: '${root.path}/documents',
      tempPath: '${root.path}/cache',
    );
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  String booksDirPath() =>
      '${AppStorage.documentsPath}${AppStorageConstants.booksDir}';

  group('BookFileStore.copyBook', () {
    test('复制源文件到 books 目录并返回绝对路径', () async {
      final source = File('${root.path}/source.epub');
      await source.writeAsBytes([1, 2, 3]);

      final result = await store.copyBook(source, 'hash1');

      expect(result.isRight(), isTrue);
      final path = result.getOrElse((l) => throw l);
      expect(path, '${booksDirPath()}/hash1.epub');
      expect(await File(path).readAsBytes(), [1, 2, 3]);
      expect(await source.exists(), isTrue);
    });

    test('moveSourceFile 为真时源文件被移走', () async {
      final source = File('${root.path}/source.epub');
      await source.writeAsBytes([1, 2, 3]);

      final result = await store.copyBook(
        source,
        'hash1',
        moveSourceFile: true,
      );

      expect(result.isRight(), isTrue);
      expect(await source.exists(), isFalse);
    });

    test('目标已存在时不覆盖', () async {
      final source = File('${root.path}/source.epub');
      await source.writeAsBytes([9]);
      final existing = File('${booksDirPath()}/hash1.epub');
      await existing.create(recursive: true);
      await existing.writeAsBytes([7, 7]);

      final result = await store.copyBook(source, 'hash1');

      expect(result.isRight(), isTrue);
      expect(await existing.readAsBytes(), [7, 7]);
    });
  });

  group('BookFileStore.writeNormalizedTxt', () {
    test('按哈希写入归一化字节并带 .txt 扩展名', () async {
      final bytes = Uint8List.fromList('归一化文本'.codeUnits);

      final result = await store.writeNormalizedTxt(bytes, 'hash2');

      expect(result.isRight(), isTrue);
      final path = result.getOrElse((l) => throw l);
      expect(path, '${booksDirPath()}/hash2.txt');
      expect(await File(path).readAsBytes(), bytes);
    });
  });
}
