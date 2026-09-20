import 'dart:io';

import 'package:archive/archive_io.dart' hide ZLibDecoder;
import 'package:path/path.dart' as p;

import 'backup_archive_guard.dart';

/// 逐条解压备份，核对实际大小与 CRC；解码或写盘失败直接向上传播。
///
/// 支持 ZIP 的 STORE、DEFLATE 与 BZIP2，不创建符号链接。调用方负责清理
/// 失败时的整个 [target]，只有本函数成功返回后才能开始恢复数据库。
Future<void> extractVerifiedBackupZip(File zip, Directory target) async {
  final input = InputFileStream(zip.path);
  try {
    // 直接读取目录，避免 ZipDecoder 在静态校验前解压符号链接内容。
    final directory = ZipDirectory()..read(input);
    final headers = directory.fileHeaders;
    if (directory.filePosition < 0 ||
        headers.length != directory.totalCentralDirectoryEntries) {
      throw const FormatException('Invalid ZIP directory');
    }
    final violation = validateBackupArchiveEntries(
      headers.map((h) => (name: h.filename, size: h.uncompressedSize)),
    );
    if (violation != null) throw BackupArchiveViolationException(violation);

    await target.create(recursive: true);
    for (final header in headers) {
      final entry = header.file!;
      final unixFileType = (header.externalFileAttributes >> 16) & 0xf000;
      final compression = switch (header.compressionMethod) {
        0 => CompressionType.none,
        8 => CompressionType.deflate,
        12 => CompressionType.bzip2,
        _ => null,
      };
      if (unixFileType == 0xa000 ||
          entry.flags & 1 != 0 ||
          entry.filename != header.filename ||
          entry.uncompressedSize != header.uncompressedSize ||
          entry.crc32 != header.crc32 ||
          compression == null ||
          entry.compressionMethod != compression) {
        throw FormatException(
          'Unsupported or inconsistent ZIP entry',
          header.filename,
        );
      }
      final name = header.filename.replaceAll('\\', '/');
      final filePath = p.normalize(p.join(target.path, name));
      if (!p.isWithin(target.path, filePath)) {
        throw const BackupArchiveViolationException(
          BackupArchiveViolation.unsafePath,
        );
      }
      if (name.endsWith('/')) {
        await Directory(filePath).create(recursive: true);
        continue;
      }

      final output = _VerifiedBackupOutput(filePath, header.uncompressedSize);
      try {
        final content = entry.getStream(decompress: false);
        switch (header.compressionMethod) {
          case 0:
            output.writeStream(content);
          case 8:
            // archive 的原生解码器会聚集全部输出；原生 sink 直接逐块校验写盘。
            final decoder = ZLibDecoder(
              raw: true,
            ).startChunkedConversion(_BackupOutputSink(output));
            try {
              while (!content.isEOS) {
                final size = content.length.clamp(0, 64 * 1024);
                decoder.add(content.readBytes(size).toUint8List());
              }
            } finally {
              decoder.close();
            }
          case 12:
            BZip2Decoder().decodeStream(content, output);
        }
        if (output.length != header.uncompressedSize ||
            output.crc != header.crc32) {
          throw FormatException('ZIP size or CRC mismatch', header.filename);
        }
      } finally {
        await output.close();
      }
    }
  } finally {
    await input.close();
  }
}

/// 静态上限已检查声明大小；实际输出不能超过声明，累计量也随之受限。
class _VerifiedBackupOutput extends OutputFileStream {
  final FileHandle _handle;
  final int expectedSize;
  int crc = 0;

  _VerifiedBackupOutput(String path, int expectedSize)
    : this._(FileHandle(path, mode: FileAccess.write), expectedSize);

  _VerifiedBackupOutput._(this._handle, this.expectedSize)
    : super.withFileHandle(_handle, bufferSize: 64 * 1024);

  @override
  Future<void> close() async {
    try {
      flush();
    } finally {
      await _handle.close();
    }
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (this.length + count > expectedSize) {
      throw const FormatException('ZIP entry exceeds its declared size');
    }
    crc = getCrc32(
      count == bytes.length ? bytes : bytes.sublist(0, count),
      crc,
    );
    super.writeBytes(bytes, length: count);
  }

  @override
  void writeByte(int value) => writeBytes([value]);
}

class _BackupOutputSink implements Sink<List<int>> {
  final _VerifiedBackupOutput output;

  _BackupOutputSink(this.output);

  @override
  void add(List<int> data) => output.writeBytes(data);

  @override
  void close() => output.flush();
}
