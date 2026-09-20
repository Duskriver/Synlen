import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'package:synlen/src/features/library/data/parsers/txt_book_parser.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/data/readium_txt_publication_cache.dart';

void main() {
  late Directory directory;
  late File source;
  late ReadiumTxtPublicationCache cache;
  late ReaderManifestView manifest;
  const text =
      '前言\nPREFACE & <xml>\n第一卷 春 & 秋\n卷前正文\n第一章 起点\nA & B < C "D"\nemoji 😀\u0000\n第二章 终点\nFINAL_SENTENCE_END\n';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('readium-txt-test-');
    final parsed = const TxtBookParser()
        .parseFromText(text)
        .getOrElse((error) => throw error);
    source = await File(
      p.join(directory.path, 'source.txt'),
    ).writeAsBytes(parsed.normalizedUtf8);
    manifest = (spine: parsed.spine, toc: parsed.toc);
    cache = ReadiumTxtPublicationCache(
      cacheDirectory: p.join(directory.path, 'cache'),
    );
  });

  tearDown(() async => directory.delete(recursive: true));

  Future<String> prepare({
    String title = '标题 & < >',
    ReaderManifestView? structure,
  }) => cache.prepare(
    sourcePath: source.path,
    title: title,
    author: '作者 & "名字"',
    manifest: structure ?? manifest,
  );

  Archive read(String path) =>
      ZipDecoder().decodeBytes(File(path).readAsBytesSync(), verify: true);
  String entry(Archive archive, String name) =>
      utf8.decode(archive.findFile(name)!.content);

  test('有效 EPUB 覆盖全部正文，目录层级、XML 转义和稳定锚点可恢复', () async {
    final archive = read(await prepare());
    expect(archive.first.name, 'mimetype');
    expect(archive.first.compression, CompressionType.none);
    expect(entry(archive, 'mimetype'), 'application/epub+zip');
    final package = XmlDocument.parse(entry(archive, 'package.opf'));
    expect(package.findAllElements('itemref').length, manifest.spine.length);
    final nav = XmlDocument.parse(entry(archive, 'nav.xhtml'));
    expect(nav.findAllElements('ol').length, greaterThan(1));
    for (final link in nav.findAllElements('a')) {
      final path = link.getAttribute('href')!.split('#').first;
      expect(archive.findFile(path), isNotNull);
    }
    final body = StringBuffer();
    for (final chapter in manifest.spine) {
      final xml = XmlDocument.parse(entry(archive, chapter.href));
      expect(xml.findAllElements('body').single.getAttribute('id'), 'top');
      final elements = xml.findAllElements('body').single.childElements;
      expect(elements.first.getAttribute('id'), 'p-0');
      body.writeln(xml.findAllElements('body').single.innerText);
    }
    for (final expected in [
      'PREFACE & <xml>',
      '卷前正文',
      'A & B < C "D"',
      'emoji 😀�',
      'FINAL_SENTENCE_END',
    ]) {
      expect(body.toString(), contains(expected));
    }
    expect(package.findAllElements('dc:title').single.innerText, '标题 & < >');
    expect(package.findAllElements('dc:creator').single.innerText, '作者 & "名字"');
  });

  test('并发生成合并为一个原子文件，相同内容复用，源字节和元数据变化失效', () async {
    final paths = await Future.wait([prepare(), prepare(), prepare()]);
    expect(paths.toSet(), hasLength(1));
    final original = paths.first;
    final modified = File(original).lastModifiedSync();
    expect(await prepare(), original);
    expect(File(original).lastModifiedSync(), modified);
    expect(Directory(p.join(directory.path, 'cache')).listSync().length, 1);
    final changed = text.replaceFirst('FINAL', 'OTHER');
    await source.writeAsString(changed);
    final rebuilt = await prepare();
    expect(rebuilt, isNot(original));
    final archive = read(rebuilt);
    expect(
      entry(archive, manifest.spine.last.href),
      contains('OTHER_SENTENCE_END'),
    );
    expect(await prepare(title: '新标题'), isNot(rebuilt));
  });

  test('拒绝范围缺口、过期清单及路径错误，不生成截断正文或留下临时文件', () async {
    final bad = [
      for (final item in manifest.spine) SpineItem.fromJson(item.toJson()),
    ];
    bad.first.sourceRange = '1-2';
    await expectLater(
      prepare(structure: (spine: bad, toc: manifest.toc)),
      throwsStateError,
    );
    await source.writeAsString('$text新增尾部');
    await expectLater(prepare(), throwsStateError);
    bad.first.href = '../outside.xhtml';
    await expectLater(
      prepare(structure: (spine: bad, toc: manifest.toc)),
      throwsStateError,
    );
    expect(Directory(p.join(directory.path, 'cache')).existsSync(), isFalse);
  });
}
