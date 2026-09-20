import 'dart:convert';

import 'package:archive/archive.dart';

/// 小型真实 EPUB，供内容供给与设备测试使用。
List<int> testEpubBytes({
  String? chapter,
  Map<String, List<int>> extra = const {},
}) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.noCompress(
        'mimetype',
        20,
        utf8.encode('application/epub+zip'),
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'META-INF/container.xml',
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0"><rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/package.opf',
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:test:a&amp;b</dc:identifier><dc:title>测试 EPUB</dc:title><dc:language>zh</dc:language><meta property="dcterms:modified">2000-01-01T00:00:00Z</meta></metadata><manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml" ${chapter?.contains('<svg') == true ? 'properties="svg"' : ''}/><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/></manifest><spine><itemref idref="chapter"/></spine></package>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/nav.xhtml',
        '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>目录</title></head><body><nav epub:type="toc"><ol><li><a href="chapter.xhtml">正文</a></li></ol></nav></body></html>',
      ),
    )
    ..addFile(
      ArchiveFile.string(
        'OEBPS/chapter.xhtml',
        chapter ??
            '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>正文</title></head><body><p>普通正文 &amp; 原样保留。</p></body></html>',
      ),
    );
  for (final entry in extra.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}
