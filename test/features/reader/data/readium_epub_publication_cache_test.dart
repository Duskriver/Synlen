import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';
import 'package:synlen/src/features/reader/data/readium_epub_publication_cache.dart';

import '../../../helpers/epub_fixture.dart';

void main() {
  late Directory directory;
  late File source;
  late ReadiumEpubPublicationCache cache;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('epub-security-');
    source = File(p.join(directory.path, 'source.epub'));
    cache = ReadiumEpubPublicationCache(
      cacheDirectory: p.join(directory.path, 'cache'),
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test('重建缓存实例后仍能复用校验结果，损坏的索引可重建', () async {
    await source.writeAsBytes(testEpubBytes());
    await cache.prepare(source.path);
    final reopened = ReadiumEpubPublicationCache(
      cacheDirectory: cache.cacheDirectory,
    );

    expect(await reopened.prepare(source.path), source.path);
    final index = Directory(cache.cacheDirectory)
        .listSync()
        .whereType<File>()
        .singleWhere((file) => p.basename(file.path).contains('-source-'));
    for (final bytes in [
      utf8.encode('incomplete'),
      [0xff],
    ]) {
      await index.writeAsBytes(bytes);
      expect(await reopened.prepare(source.path), source.path);
      expect(await index.readAsBytes(), isNot(bytes));
    }
  });

  test('源文件等长改写且恢复修改时间，也不能复用旧校验结果', () async {
    final original = testEpubBytes();
    await source.writeAsBytes(original);
    await cache.prepare(source.path);
    final modified = await source.lastModified();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    original[_find(original, utf8.encode('application/epub+zip'))] ^= 1;
    await source.writeAsBytes(original);
    await source.setLastModified(modified);

    await expectLater(cache.prepare(source.path), throwsFormatException);
  });

  test('净化副本被清理后重新生成，不返回失效的缓存路径', () async {
    await source.writeAsBytes(
      testEpubBytes(chapter: '<html><body onload="bad()">正文</body></html>'),
    );
    final prepared = await cache.prepare(source.path);
    await File(prepared).delete();

    expect(await cache.prepare(source.path), prepared);
    expect(await File(prepared).exists(), isTrue);
  });

  test('普通 EPUB 直接保留原文件，缓存检查结果随源内容变化失效', () async {
    final original = testEpubBytes();
    await source.writeAsBytes(original);
    expect(await cache.prepare(source.path), source.path);
    expect(await cache.prepare(source.path), source.path);
    expect(await source.readAsBytes(), original);
    await source.writeAsBytes(
      testEpubBytes(
        chapter:
            '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>正文</title></head><body onload="bad()"><p>新正文</p></body></html>',
      ),
    );
    final sanitized = await cache.prepare(source.path);
    expect(sanitized, isNot(source.path));
    expect(await cache.prepare(source.path), sanitized);
  });

  test('标准 XHTML DOCTYPE、声明与 HTML 命名实体保持兼容', () async {
    const chapter = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>标题</title></head><body><p>A&nbsp;B &copy; &mdash;</p></body></html>''';
    final original = testEpubBytes(chapter: chapter);
    await source.writeAsBytes(original);
    expect(await cache.prepare(source.path), source.path);
    expect(await source.readAsBytes(), original);
    await source.writeAsBytes(
      testEpubBytes(
        chapter: chapter.replaceFirst('<body>', '<body onclick="bad()">'),
      ),
    );
    final prepared = await cache.prepare(source.path);
    final archive = ZipDecoder().decodeBytes(
      await File(prepared).readAsBytes(),
    );
    final parsed = XmlDocument.parse(
      utf8.decode(archive.findFile('OEBPS/chapter.xhtml')!.content),
    );
    expect(parsed.innerText, contains('A\u00a0B © —'));
    expect(
      parsed.findAllElements('body').single.getAttribute('onclick'),
      isNull,
    );
  });

  test('移除带命名空间和 CDATA 的脚本、事件、实体混淆 URL，保留字体与 OPF 原字节', () async {
    final font = List<int>.generate(2000, (index) => index % 256);
    final encryption = utf8.encode(
      '<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><EncryptedData xmlns="http://www.w3.org/2001/04/xmlenc#"><EncryptionMethod Algorithm="http://www.idpf.org/2008/embedding"/><CipherData><CipherReference URI="OEBPS/Fonts/font.ttf"/></CipherData></EncryptedData></encryption>',
    );
    final input = testEpubBytes(
      chapter: '''<?xml version="1.0" encoding="UTF-8"?>
<h:html xmlns:h="http://www.w3.org/1999/xhtml" xmlns:s="http://www.w3.org/2000/svg" xmlns:on="urn:example:kept" xmlns:xlink="http://www.w3.org/1999/xlink"><h:head><h:title>保留标题</h:title><h:script><![CDATA[window.pwned = 1;]]></h:script></h:head><h:body onload="pwn()"><h:p id="keep"><![CDATA[<script>这里是可见文本</script>]]>正文 &amp; 保留</h:p><h:a href="java&#x0a;script:bad()" onclick="bad()">链接</h:a><s:svg viewBox="0 0 10 10"><s:script>bad()</s:script><s:circle cx="5" cy="5" r="4" onmouseover="bad()"/><s:a xlink:href="javascript:bad()"><s:text>图中链接</s:text></s:a><s:set attributeName="href" to="javascript:bad()"/></s:svg><h:iframe srcdoc="&lt;script&gt;bad()&lt;/script&gt;"/></h:body></h:html>''',
      extra: {
        'OEBPS/Fonts/font.ttf': font,
        'META-INF/encryption.xml': encryption,
      },
    );
    await source.writeAsBytes(input);
    final results = await Future.wait([
      cache.prepare(source.path),
      cache.prepare(source.path),
    ]);
    expect(results.toSet(), hasLength(1));
    final output = ZipDecoder().decodeBytes(
      await File(results.first).readAsBytes(),
    );
    final original = ZipDecoder().decodeBytes(input);
    for (final name in [
      'OEBPS/Fonts/font.ttf',
      'META-INF/encryption.xml',
      'OEBPS/package.opf',
      'OEBPS/nav.xhtml',
    ]) {
      expect(output.findFile(name)!.content, original.findFile(name)!.content);
    }
    final document = XmlDocument.parse(
      utf8.decode(output.findFile('OEBPS/chapter.xhtml')!.content),
    );
    expect(document.rootElement.namespaceUri, 'http://www.w3.org/1999/xhtml');
    expect(document.rootElement.getAttribute('xmlns:on'), 'urn:example:kept');
    final elements = document.descendants.whereType<XmlElement>();
    expect(
      elements.where(
        (node) => const {'script', 'iframe', 'set'}.contains(node.localName),
      ),
      isEmpty,
    );
    expect(
      elements.firstWhere((node) => node.localName == 'circle').namespaceUri,
      'http://www.w3.org/2000/svg',
    );
    expect(
      elements
          .expand((node) => node.attributes)
          .where(
            (attribute) =>
                attribute.localName == 'onclick' ||
                attribute.localName == 'onload' ||
                attribute.value.startsWith('javascript:'),
          ),
      isEmpty,
    );
    expect(document.innerText, contains('<script>这里是可见文本</script>正文 & 保留'));
    expect(output.first.name, 'mimetype');
    expect(output.first.compression, CompressionType.none);
  });

  test('不支持的 XML 或自定义 DTD 直接失败，不把原书送入原生引擎', () async {
    for (final chapter in [
      '<html><body><script>broken',
      '<!DOCTYPE html [<!ENTITY evil "javascript:bad()">]><html><body><a href="&evil;">实体</a></body></html>',
    ]) {
      await source.writeAsBytes(testEpubBytes(chapter: chapter));
      await expectLater(cache.prepare(source.path), throwsA(isA<Exception>()));
    }
    expect(Directory(p.join(directory.path, 'cache')).listSync(), isEmpty);
  });

  test('真实 CRC 损坏被拒绝，不能依赖 archive 的 verify 参数', () async {
    final bytes = testEpubBytes();
    // 首项 mimetype 使用 STORE；仅篡改正文，保留两处 CRC 声明。
    final offset = _find(bytes, utf8.encode('application/epub+zip'));
    bytes[offset] ^= 1;
    await source.writeAsBytes(bytes);
    await expectLater(cache.prepare(source.path), throwsFormatException);
    expect(Directory(p.join(directory.path, 'cache')).listSync(), isEmpty);
  });
}

int _find(List<int> source, List<int> pattern) {
  for (var i = 0; i <= source.length - pattern.length; i++) {
    if (List.generate(
      pattern.length,
      (j) => source[i + j] == pattern[j],
    ).every((matches) => matches)) {
      return i;
    }
  }
  throw StateError('fixture 未包含目标内容');
}
