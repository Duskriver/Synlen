import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/file_handling/backup_archive_extractor.dart';
import 'package:synlen/src/core/file_handling/backup_archive_guard.dart';

void main() {
  late Directory root;
  late Directory target;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-zip-extractor-');
    target = Directory('${root.path}/extracted');
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> zip(Archive archive) async =>
      File('${root.path}/backup.zip')
        ..writeAsBytesSync(ZipEncoder().encode(archive));

  for (final compression in [
    CompressionType.none,
    CompressionType.deflate,
    CompressionType.bzip2,
  ]) {
    test('$compression 跨多个读写缓冲区解压后字节完全一致', () async {
      final random = Random(42);
      final bytes = Uint8List.fromList(
        List.generate(160 * 1024, (_) => random.nextInt(256)),
      );
      final archive = Archive()
        ..addFile(ArchiveFile.directory('books/'))
        ..addFile(
          ArchiveFile.bytes('books/book.bin', bytes)..compression = compression,
        )
        ..addFile(ArchiveFile.bytes('empty', []));

      await extractVerifiedBackupZip(await zip(archive), target);

      expect(await File('${target.path}/books/book.bin').readAsBytes(), bytes);
      expect(await File('${target.path}/empty').length(), 0);
    });
  }

  test('路径越界在写盘前拒绝', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../outside.txt', 'outside'));

    await expectLater(
      extractVerifiedBackupZip(await zip(archive), target),
      throwsA(isA<BackupArchiveViolationException>()),
    );

    expect(target.existsSync(), isFalse);
    expect(File('${root.path}/outside.txt').existsSync(), isFalse);
  });

  test('符号链接不被创建或当作普通书籍恢复', () async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('books/book.txt', '../outside.txt')..mode = 0xa1ff,
      );

    await expectLater(
      extractVerifiedBackupZip(await zip(archive), target),
      throwsA(isA<FormatException>()),
    );

    expect(target.listSync(recursive: true, followLinks: false), isEmpty);
  });

  test('未知压缩方法不能作为未压缩正文写盘', () async {
    final archive = Archive()
      ..addFile(ArchiveFile.noCompress('book.txt', 4, [1, 2, 3, 4]));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final data = ByteData.sublistView(bytes);
    for (var offset = 0; offset + 12 < bytes.length; offset++) {
      final signature = data.getUint32(offset, Endian.little);
      if (signature == 0x04034b50 || signature == 0x02014b50) {
        data.setUint16(
          offset + (signature == 0x04034b50 ? 8 : 10),
          99,
          Endian.little,
        );
      }
    }
    final file = File('${root.path}/backup.zip')..writeAsBytesSync(bytes);

    await expectLater(
      extractVerifiedBackupZip(file, target),
      throwsA(isA<FormatException>()),
    );

    expect(target.listSync(recursive: true), isEmpty);
  });
}
