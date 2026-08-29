import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// TXT 文件实际使用的字符编码
enum TxtEncoding { utf8, utf16le, utf16be, gbk }

/// TXT 解码结果：全文文本与识别出的编码
class TxtDecodeResult {
  final String text;
  final TxtEncoding encoding;

  const TxtDecodeResult({required this.text, required this.encoding});
}

/// TXT 文件解码器。
///
/// 识别顺序：BOM（UTF-16 / UTF-8）→ UTF-8 严格解码 → GBK 兜底。
/// 中文 TXT 最常见的是 UTF-8 与 GBK 两类；GBK 解码对非法字节
/// 宽容（任何序列都不失败），因此放在 UTF-8 严格校验之后兜底。
class TxtDecoder {
  const TxtDecoder();

  /// 二进制判定阈值：采样区内控制字符（不含 \t\n\r）占比超过该值视为二进制
  static const double maxBinaryControlRatio = 0.01;

  /// 二进制判定的采样字符数（全文采样代价高，取开头一段足够）
  static const int binarySampleLength = 8192;

  TxtDecodeResult decode(Uint8List bytes) {
    final TxtDecodeResult result;

    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        result = TxtDecodeResult(
          text: _stripBom(
            _decodeUtf16(bytes, littleEndian: true, skipBytes: 2),
          ),
          encoding: TxtEncoding.utf16le,
        );
        return _guardBinary(result);
      }
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        result = TxtDecodeResult(
          text: _stripBom(
            _decodeUtf16(bytes, littleEndian: false, skipBytes: 2),
          ),
          encoding: TxtEncoding.utf16be,
        );
        return _guardBinary(result);
      }
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return _guardBinary(
        TxtDecodeResult(
          text: _stripBom(utf8.decode(bytes, allowMalformed: true)),
          encoding: TxtEncoding.utf8,
        ),
      );
    }

    try {
      return _guardBinary(
        TxtDecodeResult(text: utf8.decode(bytes), encoding: TxtEncoding.utf8),
      );
    } on FormatException {
      // 非 UTF-8 字节序列，继续尝试 GBK
    }

    return _guardBinary(
      TxtDecodeResult(text: gbk.decode(bytes), encoding: TxtEncoding.gbk),
    );
  }

  /// 二进制内容守卫：任何字节序列都能被 GBK/Latin-1 解码，
  /// 通过控制字符占比拦截误导入的二进制文件（如改后缀的 PDF）
  static TxtDecodeResult _guardBinary(TxtDecodeResult result) {
    if (_looksBinary(result.text)) {
      throw const FormatException('TXT 内容疑似二进制数据，非文本文件');
    }
    return result;
  }

  static bool _looksBinary(String text) {
    final sampleLength = text.length > binarySampleLength
        ? binarySampleLength
        : text.length;
    if (sampleLength == 0) return false;

    var controlCount = 0;
    for (var i = 0; i < sampleLength; i++) {
      final code = text.codeUnitAt(i);
      if (code < 0x20 && code != 0x09 && code != 0x0A && code != 0x0D) {
        controlCount++;
      }
    }
    return controlCount / sampleLength > maxBinaryControlRatio;
  }

  /// 手写 UTF-16 解码（dart:convert 无内置 codec）。
  /// 按码元迭代写入，代理对在写入时自然组合成完整字符。
  static String _decodeUtf16(
    Uint8List bytes, {
    required bool littleEndian,
    int skipBytes = 0,
  }) {
    final buffer = StringBuffer();
    for (var i = skipBytes; i + 1 < bytes.length; i += 2) {
      final unit = littleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      buffer.writeCharCode(unit);
    }
    return buffer.toString();
  }

  /// 去掉解码后残留的 BOM 字符
  static String _stripBom(String text) {
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }
}
