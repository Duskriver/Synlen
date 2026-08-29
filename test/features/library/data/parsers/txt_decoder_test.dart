import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/parsers/txt_decoder.dart';

void main() {
  const decoder = TxtDecoder();

  /// 手写 UTF-16 编码（测试用，与解码端逻辑互逆）
  Uint8List encodeUtf16(
    String text, {
    required bool littleEndian,
    bool withBom = true,
  }) {
    final bytes = <int>[];
    if (withBom) {
      bytes.addAll(littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]);
    }
    for (var i = 0; i < text.length; i++) {
      final unit = text.codeUnitAt(i);
      if (littleEndian) {
        bytes.add(unit & 0xFF);
        bytes.add(unit >> 8);
      } else {
        bytes.add(unit >> 8);
        bytes.add(unit & 0xFF);
      }
    }
    return Uint8List.fromList(bytes);
  }

  group('TxtDecoder 编码识别', () {
    test('无 BOM 的 UTF-8 文本识别为 utf8', () {
      const text = '第一章 你好，世界！\n正文内容。';
      final result = decoder.decode(Uint8List.fromList(utf8.encode(text)));

      expect(result.encoding, TxtEncoding.utf8);
      expect(result.text, text);
    });

    test('带 UTF-8 BOM 的文本识别为 utf8 且去掉 BOM', () {
      final bytes = Uint8List.fromList([
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode('第二章 标题\n内容'),
      ]);
      final result = decoder.decode(bytes);

      expect(result.encoding, TxtEncoding.utf8);
      expect(result.text, '第二章 标题\n内容');
      expect(result.text.startsWith('\uFEFF'), isFalse);
    });

    test('UTF-16LE（FF FE BOM）识别为 utf16le', () {
      const text = '第三章 数据\n多行文本';
      final result = decoder.decode(encodeUtf16(text, littleEndian: true));

      expect(result.encoding, TxtEncoding.utf16le);
      expect(result.text, text);
    });

    test('UTF-16BE（FE FF BOM）识别为 utf16be', () {
      const text = '第四章 编码';
      final result = decoder.decode(encodeUtf16(text, littleEndian: false));

      expect(result.encoding, TxtEncoding.utf16be);
      expect(result.text, text);
    });

    test('UTF-16 代理对（emoji 等非 BMP 字符）完整还原', () {
      const text = '第五章 😀 表情';
      final result = decoder.decode(encodeUtf16(text, littleEndian: true));

      expect(result.encoding, TxtEncoding.utf16le);
      expect(result.text, text);
    });

    test('GBK 编码的中文文本识别为 gbk 并正确还原', () {
      const text = '第一章 闺塾\n春蚕到死丝方尽，蜡炬成灰泪始干。';
      final bytes = Uint8List.fromList(gbk.encode(text));
      final result = decoder.decode(bytes);

      expect(result.encoding, TxtEncoding.gbk);
      expect(result.text, text);
    });

    test('空字节数组按 utf8 解码为空文本', () {
      final result = decoder.decode(Uint8List(0));

      expect(result.encoding, TxtEncoding.utf8);
      expect(result.text, isEmpty);
    });
  });

  group('TxtDecoder 二进制守卫', () {
    test('合法 UTF-8 但控制字符占比超限的内容被拒绝', () {
      // 每 20 个字符夹 1 个控制字符（5% > 1% 阈值）
      final text =
          List.filled(500, '正常文本内容\n').join() + List.filled(200, '\x01').join();
      expect(
        () => decoder.decode(Uint8List.fromList(utf8.encode(text))),
        throwsA(isA<FormatException>()),
      );
    });

    test('非 UTF-8 且 GBK 解码后控制字符超限的二进制被拒绝（如改后缀的 PDF）', () {
      // 0xFF 非法 UTF-8 且非法 GBK 首字节（解码为替换符），0x01 为控制字符；
      // 首两字节刻意避开 FF FE / FE FF 以免误入 UTF-16 分支
      final bytes = Uint8List.fromList(
        List.generate(200, (i) => i.isEven ? 0xFF : 0x01),
      );
      expect(() => decoder.decode(bytes), throwsA(isA<FormatException>()));
    });

    test('\\t \\n \\r 不计入控制字符，正常排版文本不误判', () {
      final text = '缩进\t制表符\n换行\r\n回车\n' * 100;
      final result = decoder.decode(Uint8List.fromList(utf8.encode(text)));

      expect(result.encoding, TxtEncoding.utf8);
      expect(result.text, text);
    });
  });
}
