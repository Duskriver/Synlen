import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' hide ZLibDecoder;

/// 按 ZIP 路径读取一张封面；缺失返回 null，损坏或超限向调用方抛错。
///
/// 只解压目标条目，支持 STORE / DEFLATE，实际输出最多 50 MiB。
/// 同步文件读取与解压必须由调用方放到 isolate 中执行。
Uint8List? readEpubCover(({String epubPath, String coverPath}) request) {
  const maxBytes = 50 * 1024 * 1024;
  final input = InputFileStream(request.epubPath);
  try {
    final directory = ZipDirectory()..read(input);
    if (directory.filePosition < 0 ||
        directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.fileHeaders.length !=
            directory.totalCentralDirectoryEntries) {
      throw const FormatException('Invalid EPUB ZIP directory');
    }
    final path = _normalizePath(request.coverPath);
    // 与旧后端一致，归一化后重名的条目取最后一个。
    ZipFileHeader? header;
    for (final candidate in directory.fileHeaders) {
      if (_normalizePath(candidate.filename) == path) header = candidate;
    }
    if (header == null) return null;
    if (header.uncompressedSize < 0 || header.uncompressedSize > maxBytes) {
      throw const FormatException('EPUB cover exceeds size limit');
    }

    // archive 会用中央目录覆盖部分本地头字段，因此直接核对原始字段。
    input.setPosition(header.localHeaderOffset);
    final signature = input.readUint32();
    input.readUint16();
    final flags = input.readUint16();
    final method = input.readUint16();
    input.skip(4);
    final crc = input.readUint32();
    final compressedSize = input.readUint32();
    final size = input.readUint32();
    final nameLength = input.readUint16();
    final extraLength = input.readUint16();
    final dataOffset = header.localHeaderOffset + 30 + nameLength + extraLength;
    final hasDescriptor = flags & 8 != 0;
    final entry = header.file;
    if (signature != 0x04034b50 ||
        flags != header.generalPurposeBitFlag ||
        flags & 1 != 0 ||
        (header.externalFileAttributes >> 16) & 0xf000 == 0xa000 ||
        header.filename.endsWith('/') ||
        entry == null ||
        entry.filename != header.filename ||
        method != header.compressionMethod ||
        (method != 0 && method != 8) ||
        header.diskNumberStart != 0 ||
        header.compressedSize < 0 ||
        dataOffset + header.compressedSize > directory.centralDirectoryOffset ||
        (!hasDescriptor &&
            (crc != header.crc32 ||
                (size != 0xffffffff && size != header.uncompressedSize) ||
                (compressedSize != 0xffffffff &&
                    compressedSize != header.compressedSize)))) {
      throw const FormatException('Unsupported or inconsistent EPUB cover');
    }

    final output = _CoverBytes(header.uncompressedSize);
    final source = entry.getStream(decompress: false);
    if (source.length != header.compressedSize) {
      throw const FormatException('Truncated EPUB cover');
    }
    if (method == 0) {
      while (!source.isEOS) {
        output.add(
          source.readBytes(source.length.clamp(0, 65536)).toUint8List(),
        );
      }
    } else {
      // 原生流式解码逐块检查大小；不能先聚集不受限的全部解压输出。
      final decoder = ZLibDecoder(raw: true).startChunkedConversion(output);
      try {
        while (!source.isEOS) {
          decoder.add(
            source.readBytes(source.length.clamp(0, 65536)).toUint8List(),
          );
        }
      } finally {
        decoder.close();
      }
    }
    if (output.bytes.length != header.uncompressedSize ||
        output.crc != header.crc32) {
      throw const FormatException('EPUB cover size or CRC mismatch');
    }
    return output.bytes.takeBytes();
  } finally {
    input.closeSync();
  }
}

/// 保持 ZIP 查找的兼容规则：反斜杠转斜杠，剥离前导 / 与 ./。
String _normalizePath(String path) {
  var result = path.replaceAll('\\', '/');
  while (true) {
    if (result.startsWith('/')) {
      result = result.substring(1);
    } else if (result.startsWith('./')) {
      result = result.substring(2);
    } else {
      return result;
    }
  }
}

class _CoverBytes implements Sink<List<int>> {
  final int expectedSize;
  final bytes = BytesBuilder(copy: false);
  int crc = 0;

  _CoverBytes(this.expectedSize);

  @override
  void add(List<int> data) {
    if (bytes.length + data.length > expectedSize) {
      throw const FormatException('EPUB cover exceeds declared size');
    }
    crc = getCrc32(data, crc);
    bytes.add(data);
  }

  @override
  void close() {}
}
