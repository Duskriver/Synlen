import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/features/library/data/parsers/txt_book_parser.dart';
import 'package:synlen/src/features/library/data/parsers/txt_chapter_splitter.dart';

void main() {
  const parser = TxtBookParser();
  const splitter = TxtChapterSplitter();

  /// 取 Either 右值；测试中断言的均为成功路径，left 直接失败
  TxtBookParseResult unwrap(Either<String, TxtBookParseResult> result) {
    expect(result.isRight(), isTrue);
    return result.getOrElse((l) => throw StateError('unexpected left: $l'));
  }

  group('TxtChapterSplitter.isHeadingLine', () {
    test('识别中文章节标题', () {
      expect(splitter.isHeadingLine('第一章 开始'), isTrue);
      expect(splitter.isHeadingLine('第1章'), isTrue);
      expect(splitter.isHeadingLine('第十二章：转折'), isTrue);
      expect(splitter.isHeadingLine('  第三回   '), isTrue);
      expect(splitter.isHeadingLine('第１２章 全角数字'), isTrue);
    });

    test('识别卷 / 英文 / 特殊 / 纯数字标题', () {
      expect(splitter.isHeadingLine('第一卷 风起'), isTrue);
      expect(splitter.isHeadingLine('chapter 3'), isTrue);
      expect(splitter.isHeadingLine('Chapter 12: The End'), isTrue);
      expect(splitter.isHeadingLine('楔子'), isTrue);
      expect(splitter.isHeadingLine('番外：日常'), isTrue);
      expect(splitter.isHeadingLine('42'), isTrue);
    });

    test('拒绝正文与非法标题', () {
      expect(splitter.isHeadingLine('这是一段正文，不是标题。'), isFalse);
      expect(splitter.isHeadingLine(''), isFalse);
      expect(splitter.isHeadingLine('12345'), isFalse); // 纯数字限 1~4 位
      // 超长行不视为标题（防正文误判）
      expect(splitter.isHeadingLine('第一章 ${'长' * 60}'), isFalse);
    });
  });

  group('TxtChapterSplitter.split', () {
    test('按章节标题切分且区间连续覆盖全文', () {
      const text = '第一章 开始\n内容一\n第二章 继续\n内容二\n';
      final chapters = splitter.split(text);

      expect(chapters.length, 2);
      expect(chapters[0].title, '第一章 开始');
      expect(chapters[0].hasHeading, isTrue);
      expect(chapters[1].title, '第二章 继续');

      // 区间连续覆盖 [0, length)
      expect(chapters.first.start, 0);
      expect(chapters.last.end, text.length);
      for (var i = 1; i < chapters.length; i++) {
        expect(chapters[i].start, chapters[i - 1].end);
      }
    });

    test('兼容 \\r\\n 与 \\r 换行', () {
      const text = '第一章 A\r\n内容\r\n第二章 B\r内容\r';
      final chapters = splitter.split(text);

      expect(chapters.length, 2);
      expect(chapters[1].title, '第二章 B');
    });

    test('首个标题前的非空内容归为引导块', () {
      const text = '本书简介\n一些介绍文字\n第一章 开始\n正文';
      final chapters = splitter.split(text);

      expect(chapters.length, 2);
      expect(chapters[0].hasHeading, isFalse);
      expect(chapters[0].title, '本书简介');
      expect(chapters[1].title, '第一章 开始');
      expect(chapters[0].end, chapters[1].start);
    });

    test('卷标题标记 isVolume', () {
      const text = '第一卷 风起\n第一章 A\n内容\n第二卷 云涌\n第二章 B\n内容';
      final chapters = splitter.split(text);

      expect(chapters.length, 4);
      expect(chapters[0].isVolume, isTrue);
      expect(chapters[1].isVolume, isFalse);
      expect(chapters[2].isVolume, isTrue);
      expect(chapters[3].isVolume, isFalse);
    });

    test('无标题短文本整体为一章', () {
      const text = '没有标题的短文\n第二行';
      final chapters = splitter.split(text);

      expect(chapters.length, 1);
      expect(chapters[0].hasHeading, isFalse);
      expect(chapters[0].title, '没有标题的短文');
      expect(chapters[0].start, 0);
      expect(chapters[0].end, text.length);
    });

    test('无标题长文本按体积分割为「第 N 部分」', () {
      // 每段约 1000 字符、空行分隔，总量超过 50000 阈值
      final paragraph = '段落内容${'字' * 990}\n\n';
      final text = paragraph * 120;
      final chapters = splitter.split(text);

      expect(chapters.length, greaterThan(1));
      expect(chapters.first.title, '第 1 部分');
      expect(chapters.every((c) => !c.hasHeading), isTrue);

      // 区间连续覆盖全文
      expect(chapters.first.start, 0);
      expect(chapters.last.end, text.length);
      for (var i = 1; i < chapters.length; i++) {
        expect(chapters[i].start, chapters[i - 1].end);
      }
    });

    test('空白文本返回空列表', () {
      expect(splitter.split('   \n\n  '), isEmpty);
    });
  });

  group('TxtBookParser.chapterIndexFromPath', () {
    test('解析合法虚拟章节路径', () {
      expect(TxtBookParser.chapterIndexFromPath('txt/chapter_0.xhtml'), 0);
      expect(TxtBookParser.chapterIndexFromPath('txt/chapter_12.xhtml'), 12);
    });

    test('拒绝非法路径', () {
      expect(TxtBookParser.chapterIndexFromPath('txt/chapter_x.xhtml'), isNull);
      expect(TxtBookParser.chapterIndexFromPath('txt/chapter_1.txt'), isNull);
      expect(
        TxtBookParser.chapterIndexFromPath('other/chapter_1.xhtml'),
        isNull,
      );
      expect(
        TxtBookParser.chapterIndexFromPath('txt/chapter_1.xhtml/extra'),
        isNull,
      );
    });
  });

  group('TxtBookParser.parseFromText', () {
    final roundTrips = <String, String>{
      '前导空行': '\n\nChapter 1\nFirst sentence.\nChapter 2\nFinal sentence.',
      '混合空白与多字节字符': ' \t\r\n\r\n第一章 开始\r\n中文😀 café\r\n第二章 结束\r\n末尾🚀',
      '正文引导块': '\n介绍😀\nChapter 1\nBody.\nChapter 2\nEnd.',
      '体积边界上的代理对': '${'a' * (TxtChapterSplitter.targetPartLength - 1)}😀tail',
    };
    for (final entry in roundTrips.entries) {
      test('${entry.key}：各章节分别解码并拼接可无损还原全文', () {
        final text = entry.value;
        final chapters = splitter.split(text);
        final result = unwrap(parser.parseFromText(text));
        final reconstructed = StringBuffer();
        var previousEnd = 0;
        expect(chapters.first.start, 0);
        for (var i = 0; i < result.spine.length; i++) {
          final range = result.spine[i].sourceRange!
              .split('-')
              .map(int.parse)
              .toList();
          expect(range[0], previousEnd);
          final decoded = utf8.decode(
            result.normalizedUtf8.sublist(range[0], range[1]),
          );
          expect(decoded, text.substring(chapters[i].start, chapters[i].end));
          reconstructed.write(decoded);
          previousEnd = range[1];
        }
        expect(previousEnd, result.normalizedUtf8.length);
        expect(reconstructed.toString(), text);
        if (entry.key == '前导空行') {
          expect(result.totalChapters, 2);
          expect(result.toc.first.label, 'Chapter 1');
        }
      });
    }

    test('生成 spine：虚拟路径 + 字节范围与归一化字节流严格对齐', () {
      const text = '引子\n序幕内容\n第一章 开始\n第一章内容\n第二章 继续\n第二章内容';
      final result = unwrap(parser.parseFromText(text, fileName: '测试书.txt'));

      expect(result.totalChapters, 3);
      expect(result.spine.length, 3);

      // href 为 txt/chapter_N.xhtml，索引与路径互相对应
      for (var i = 0; i < 3; i++) {
        expect(result.spine[i].href, 'txt/chapter_$i.xhtml');
        expect(TxtBookParser.chapterIndexFromPath(result.spine[i].href), i);
      }

      // 字节范围连续覆盖整个归一化流，且切片解码后与原文一致
      final chapters = splitter.split(text);
      var expectedStart = 0;
      for (var i = 0; i < 3; i++) {
        final parts = result.spine[i].sourceRange!.split('-');
        final start = int.parse(parts[0]);
        final end = int.parse(parts[1]);
        expect(start, expectedStart);
        final slice = result.normalizedUtf8.sublist(start, end);
        expect(
          utf8.decode(slice),
          text.substring(chapters[i].start, chapters[i].end),
        );
        expectedStart = end;
      }
      expect(expectedStart, result.normalizedUtf8.length);
    });

    test('卷/章层级生成嵌套 TOC，id 按深度优先分配', () {
      const text = '第一卷 风起\n第一章 A\n内容\n第二章 B\n内容\n第二卷 云涌\n第三章 C\n内容';
      final result = unwrap(parser.parseFromText(text));
      final toc = result.toc;

      expect(toc.length, 2);

      final volume1 = toc[0];
      expect(volume1.label, '第一卷 风起');
      expect(volume1.depth, 0);
      expect(volume1.spineIndex, 0);
      expect(volume1.id, 0);
      expect(volume1.children.length, 2);
      expect(volume1.children[0].label, '第一章 A');
      expect(volume1.children[0].depth, 1);
      expect(volume1.children[0].parentId, volume1.id);
      expect(volume1.children[0].id, 1);
      expect(volume1.children[0].spineIndex, 1);
      expect(volume1.children[1].id, 2);
      expect(volume1.children[1].spineIndex, 2);

      final volume2 = toc[1];
      expect(volume2.label, '第二卷 云涌');
      expect(volume2.id, 3);
      expect(volume2.children.length, 1);
      expect(volume2.children[0].label, '第三章 C');
      expect(volume2.children[0].id, 4);
      expect(volume2.children[0].spineIndex, 4);
    });

    test('无卷时 TOC 平铺', () {
      const text = '第一章 A\n内容\n第二章 B\n内容';
      final result = unwrap(parser.parseFromText(text));
      final toc = result.toc;

      expect(toc.length, 2);
      expect(toc.every((item) => item.depth == 0), isTrue);
      expect(toc.every((item) => item.children.isEmpty), isTrue);
    });

    test('书名取文件名去扩展名，空文件名回退 Unknown Title', () {
      expect(
        unwrap(parser.parseFromText('内容', fileName: '我的书.txt')).title,
        '我的书',
      );
      expect(
        unwrap(parser.parseFromText('内容', fileName: '/a/b/小说.TXT')).title,
        '小说',
      );
      expect(unwrap(parser.parseFromText('内容')).title, 'Unknown Title');
      expect(
        unwrap(parser.parseFromText('内容', fileName: '')).title,
        'Unknown Title',
      );
    });

    test('空白文本返回 left', () {
      final result = parser.parseFromText('  \n\n ');
      expect(result.isLeft(), isTrue);
    });
  });

  group('TxtBookParser.parseFromBytes', () {
    test('GBK 字节解码后正常解析', () {
      const text = '第一章 闺塾\n春蚕到死丝方尽\n第二章 惜春\n蜡炬成灰泪始干';
      final result = unwrap(
        parser.parseFromBytes(
          Uint8List.fromList(gbk.encode(text)),
          fileName: 'gbk书.txt',
        ),
      );

      expect(result.totalChapters, 2);
      expect(result.title, 'gbk书');
      // 归一化后应为合法 UTF-8
      expect(utf8.decode(result.normalizedUtf8), text);
    });

    test('二进制内容返回 left 而非崩溃', () {
      final bytes = Uint8List.fromList(
        List.generate(200, (i) => i.isEven ? 0xFF : 0x01),
      );
      final result = parser.parseFromBytes(bytes, fileName: 'fake.txt');

      expect(result.isLeft(), isTrue);
    });
  });
}
