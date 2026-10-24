import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' hide ZLibEncoder;
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/services/epub_cover_reader.dart';

void main() {
  late Directory root;
  late File file;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('epub-cover-');
    file = File('${root.path}/book.epub');
  });
  tearDown(() => root.delete(recursive: true));

  Uint8List? read([String path = 'OEBPS/封面.png']) =>
      readEpubCover((epubPath: file.path, coverPath: path));

  for (final compression in [CompressionType.none, CompressionType.deflate]) {
    test('$compression 跨缓冲区逐字节读取，忽略无关条目', () {
      final random = Random(42);
      final data = List.generate(160 * 1024, (_) => random.nextInt(256));
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('unused.bin', Uint8List(1024 * 1024)))
        ..addFile(
          ArchiveFile.bytes('OEBPS/封面.png', data)..compression = compression,
        );
      file.writeAsBytesSync(ZipEncoder().encode(archive));
      expect(read(), data);
      expect(read('missing.png'), isNull);
    });
  }

  test('路径保留 Unicode、大小写与旧后端的前导分隔符兼容', () {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('./\\OEBPS\\封面.png', [1, 2, 3]));
    file.writeAsBytesSync(ZipEncoder().encode(archive));
    expect(read('/./OEBPS/封面.png'), [1, 2, 3]);
    expect(read('oebps/封面.png'), isNull);
  });

  test('归一化后重名取最后一个，重复读取不保留文件缓存', () {
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('OEBPS/封面.png', [1]))
      ..addFile(ArchiveFile.bytes('/OEBPS/封面.png', [2]));
    file.writeAsBytesSync(ZipEncoder().encode(archive));
    expect(read(), [2]);
    file.deleteSync();
    file.writeAsBytesSync(_zip([3]));
    expect(read(), [3]);
  });

  for (final zip64 in [false, true]) {
    for (final descriptor in [false, true]) {
      test('读取 ZIP64=$zip64、data descriptor=$descriptor 的封面', () {
        file.writeAsBytesSync(
          _zip([1, 2, 3], zip64: zip64, descriptor: descriptor),
        );
        expect(read(), [1, 2, 3]);
      });
    }
  }

  test('空封面返回空字节', () {
    file.writeAsBytesSync(_zip([]));
    expect(read(), isEmpty);
  });

  final corruptions = <String, void Function(ByteData, int)>{
    '本地与中央目录的 CRC 一致但正文不匹配': (data, central) {
      data.setUint32(14, 0, Endian.little);
      data.setUint32(central + 16, 0, Endian.little);
    },
    '声明超过 50 MiB': (data, central) {
      data.setUint32(22, 50 * 1024 * 1024 + 1, Endian.little);
      data.setUint32(central + 24, 50 * 1024 * 1024 + 1, Endian.little);
    },
    '实际输出超过伪造声明': (data, central) {
      data.setUint32(22, 1, Endian.little);
      data.setUint32(central + 24, 1, Endian.little);
    },
    '实际输出小于声明': (data, central) {
      data.setUint32(22, 100, Endian.little);
      data.setUint32(central + 24, 100, Endian.little);
    },
    '本地头大小不一致': (data, central) => data.setUint32(22, 1, Endian.little),
    '本地头未知压缩方法': (data, central) => data.setUint16(8, 99, Endian.little),
    '两端都使用未知压缩方法': (data, central) {
      data.setUint16(8, 99, Endian.little);
      data.setUint16(central + 10, 99, Endian.little);
    },
    '加密条目': (data, central) {
      data.setUint16(6, 0x801, Endian.little);
      data.setUint16(central + 8, 0x801, Endian.little);
    },
    '符号链接': (data, central) =>
        data.setUint32(central + 38, 0xa1ff0000, Endian.little),
    '目录条目数不一致': (data, central) =>
        data.setUint16(data.lengthInBytes - 12, 2, Endian.little),
    '本地文件名不一致': (data, central) => data.setUint8(30, 65),
  };
  for (final corruption in corruptions.entries) {
    test('${corruption.key} 被拒绝，之后仍可读取正常文件', () {
      final bytes = _zip(List.filled(128 * 1024, 42));
      final data = ByteData.sublistView(bytes);
      final central = data.getUint32(bytes.length - 6, Endian.little);
      corruption.value(data, central);
      file.writeAsBytesSync(bytes);
      expect(read, throwsFormatException);
      file.deleteSync();
      file.writeAsBytesSync(_zip([4]));
      expect(read(), [4]);
    });
  }

  test('缺少 ZIP 目录被拒绝', () {
    file.writeAsStringSync('not a zip');
    expect(read, throwsFormatException);
  });
}

/// 独立构造 ZIP 记录，覆盖编码库默认不生成的 descriptor 与 ZIP64。
Uint8List _zip(List<int> bytes, {bool zip64 = false, bool descriptor = false}) {
  final output = OutputMemoryStream();
  final name = utf8.encode('OEBPS/封面.png');
  final compressed = ZLibEncoder(raw: true).convert(bytes);
  final crc = getCrc32(bytes);
  final flags = 0x800 | (descriptor ? 8 : 0);
  void extra() {
    if (!zip64) return;
    output.writeUint16(1);
    output.writeUint16(16);
    output.writeUint64(bytes.length);
    output.writeUint64(compressed.length);
  }

  output.writeUint32(0x04034b50);
  output.writeUint16(zip64 ? 45 : 20);
  output.writeUint16(flags);
  output.writeUint16(8);
  output.writeUint32(0);
  output.writeUint32(descriptor ? 0 : crc);
  output.writeUint32(zip64 ? 0xffffffff : (descriptor ? 0 : compressed.length));
  output.writeUint32(zip64 ? 0xffffffff : (descriptor ? 0 : bytes.length));
  output.writeUint16(name.length);
  output.writeUint16(zip64 ? 20 : 0);
  output.writeBytes(name);
  extra();
  output.writeBytes(compressed);
  if (descriptor) {
    output.writeUint32(0x08074b50);
    output.writeUint32(crc);
    if (zip64) {
      output.writeUint64(compressed.length);
      output.writeUint64(bytes.length);
    } else {
      output.writeUint32(compressed.length);
      output.writeUint32(bytes.length);
    }
  }
  final central = output.length;
  output.writeUint32(0x02014b50);
  output.writeUint16(0x031e);
  output.writeUint16(zip64 ? 45 : 20);
  output.writeUint16(flags);
  output.writeUint16(8);
  output.writeUint32(0);
  output.writeUint32(crc);
  output.writeUint32(zip64 ? 0xffffffff : compressed.length);
  output.writeUint32(zip64 ? 0xffffffff : bytes.length);
  output.writeUint16(name.length);
  output.writeUint16(zip64 ? 20 : 0);
  output.writeUint16(0);
  output.writeUint16(0);
  output.writeUint16(0);
  output.writeUint32(0);
  output.writeUint32(0);
  output.writeBytes(name);
  extra();
  final centralSize = output.length - central;
  output.writeUint32(0x06054b50);
  output.writeUint16(0);
  output.writeUint16(0);
  output.writeUint16(1);
  output.writeUint16(1);
  output.writeUint32(centralSize);
  output.writeUint32(central);
  output.writeUint16(0);
  return output.getBytes();
}
