import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/services/book_file_probe.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

void main() {
  const probe = BookFileProbe();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('synlen_probe_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('BookFileProbe.detectFormat', () {
    test('.txt 扩展名直接判为 TXT，不做魔数嗅探', () async {
      final file = File('${tempDir.path}/book.txt');
      await file.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

      expect(await probe.detectFormat(file, 'book.txt'), BookFormat.txt);
    });

    test('ZIP 魔数把 .epub 判为 EPUB', () async {
      final file = File('${tempDir.path}/book.epub');
      await file.writeAsBytes([0x50, 0x4B, 0x03, 0x04]);

      expect(await probe.detectFormat(file, 'book.epub'), BookFormat.epub);
    });

    test('扩展名像 EPUB 但无 ZIP 魔数时回退 TXT', () async {
      final file = File('${tempDir.path}/book.epub');
      await file.writeAsBytes('纯文本内容'.codeUnits);

      expect(await probe.detectFormat(file, 'book.epub'), BookFormat.txt);
    });

    test('文件名缺失时按路径推断', () async {
      final file = File('${tempDir.path}/book.txt');
      await file.writeAsBytes([0x50, 0x4B]);

      expect(await probe.detectFormat(file, null), BookFormat.txt);
    });
  });
}
