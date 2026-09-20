import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../library/domain/book_views.dart';
import '../../library/domain/txt_chapter_path.dart';
import 'services/txt_content_service.dart';

/// TXT 的派生 EPUB 缓存。源文件始终是正文真源，缓存可以随时删除。
class ReadiumTxtPublicationCache {
  ReadiumTxtPublicationCache({required this.cacheDirectory});

  final String cacheDirectory;
  final Map<String, Future<String>> _pending = {};

  Future<String> prepare({
    required String sourcePath,
    required String title,
    required String author,
    required ReaderManifestView manifest,
  }) {
    // 先快照清单，避免调用方在压缩期间修改可变的 spine / toc。
    final metadata = jsonEncode({
      'version': 1,
      'title': title,
      'author': author,
      'spine': manifest.spine.map((item) => item.toJson()).toList(),
      'toc': manifest.toc.map((item) => item.toJson()).toList(),
    });
    final pendingKey = '$sourcePath\u0000$metadata';
    final directory = cacheDirectory;
    return _pending.putIfAbsent(
      pendingKey,
      () => Isolate.run(() => _prepare(sourcePath, directory, metadata))
          .whenComplete(() {
            _pending.remove(pendingKey);
          }),
    );
  }
}

String _prepare(String sourcePath, String directory, String metadataJson) {
  final source = File(sourcePath);
  final before = source.statSync();
  final bytes = source.readAsBytesSync();
  final after = source.statSync();
  if (before.size != after.size || before.modified != after.modified) {
    throw StateError('生成阅读文件时 TXT 源文件发生变化');
  }
  final digest = sha256.convert(bytes).toString();
  final key = sha256.convert(utf8.encode('$digest\n$metadataJson'));
  final destination = File(p.join(directory, '$key.epub'));
  if (destination.existsSync() && destination.lengthSync() > 0) {
    return destination.path;
  }

  final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
  final spine = (metadata['spine'] as List).cast<Map<String, dynamic>>();
  final toc = (metadata['toc'] as List).cast<Map<String, dynamic>>();
  if (spine.isEmpty) throw StateError('TXT 缺少正文清单');
  var offset = 0;
  final archive = Archive()
    ..addFile(
      ArchiveFile.noCompress(
        'mimetype',
        20,
        utf8.encode('application/epub+zip'),
      ),
    );

  void add(String path, String content) {
    archive.addFile(ArchiveFile.string(path, content));
  }

  for (var i = 0; i < spine.length; i++) {
    final item = spine[i];
    final href = item['href'] as String;
    final match = RegExp(
      r'^(\d+)-(\d+)$',
    ).firstMatch(item['sourceRange'] as String? ?? '');
    if (txtChapterIndexFromPath(href) != i || match == null) {
      throw StateError('TXT 章节路径或字节范围无效');
    }
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    if (start != offset || end < start || end > bytes.length) {
      throw StateError('TXT 章节范围未连续覆盖正文');
    }
    offset = end;
    final text = _xmlText(utf8.decode(bytes.sublist(start, end)));
    final document = XmlDocument.parse(
      TxtContentService.buildChapterHtml(text),
    );
    final html = document.rootElement;
    html.setAttribute('lang', 'und');
    html.setAttribute('xml:lang', 'und');
    html
        .findElements('head')
        .single
        .children
        .add(
          XmlElement(XmlName.parts('title'), [], [
            XmlText(_xmlText(metadata['title'] as String)),
          ]),
        );
    final body = html.findElements('body').single;
    body.setAttribute('id', 'top');
    var paragraph = 0;
    for (final element in body.childElements) {
      element.setAttribute('id', 'p-${paragraph++}');
    }
    add(href, document.toXmlString());
  }
  if (offset != bytes.length) {
    throw StateError('TXT 清单已过期，正文未被完整覆盖');
  }

  add(
    'META-INF/container.xml',
    '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>''',
  );
  final package = XmlBuilder();
  package.processing('xml', 'version="1.0" encoding="UTF-8"');
  package.element(
    'package',
    attributes: {
      'xmlns': 'http://www.idpf.org/2007/opf',
      'version': '3.0',
      'unique-identifier': 'book-id',
    },
    nest: () {
      package.element(
        'metadata',
        attributes: {'xmlns:dc': 'http://purl.org/dc/elements/1.1/'},
        nest: () {
          package.element(
            'dc:identifier',
            attributes: {'id': 'book-id'},
            nest: 'urn:sha256:$digest',
          );
          package.element(
            'dc:title',
            nest: _xmlText(metadata['title'] as String),
          );
          package.element(
            'dc:creator',
            nest: _xmlText(metadata['author'] as String),
          );
          package.element('dc:language', nest: 'und');
          package.element(
            'meta',
            attributes: {'property': 'dcterms:modified'},
            nest: '2000-01-01T00:00:00Z',
          );
        },
      );
      package.element(
        'manifest',
        nest: () {
          package.element(
            'item',
            attributes: {
              'id': 'nav',
              'href': 'nav.xhtml',
              'media-type': 'application/xhtml+xml',
              'properties': 'nav',
            },
          );
          for (var i = 0; i < spine.length; i++) {
            package.element(
              'item',
              attributes: {
                'id': 'chapter-$i',
                'href': spine[i]['href'] as String,
                'media-type': 'application/xhtml+xml',
              },
            );
          }
        },
      );
      package.element(
        'spine',
        nest: () {
          for (var i = 0; i < spine.length; i++) {
            package.element('itemref', attributes: {'idref': 'chapter-$i'});
          }
        },
      );
    },
  );
  add('package.opf', package.buildDocument().toXmlString());

  final nav = XmlBuilder();
  nav.processing('xml', 'version="1.0" encoding="UTF-8"');
  nav.element(
    'html',
    attributes: {
      'xmlns': 'http://www.w3.org/1999/xhtml',
      'xmlns:epub': 'http://www.idpf.org/2007/ops',
      'lang': 'und',
      'xml:lang': 'und',
    },
    nest: () {
      nav.element(
        'head',
        nest: () =>
            nav.element('title', nest: _xmlText(metadata['title'] as String)),
      );
      nav.element(
        'body',
        nest: () {
          nav.element(
            'nav',
            attributes: {'epub:type': 'toc', 'id': 'toc'},
            nest: () {
              void entries(List<Map<String, dynamic>> items) {
                nav.element(
                  'ol',
                  nest: () {
                    for (final item in items) {
                      final href = item['href'] as Map<String, dynamic>;
                      final path = href['path'] as String;
                      if (!spine.any((chapter) => chapter['href'] == path)) {
                        throw StateError('TXT 目录指向不存在的正文');
                      }
                      nav.element(
                        'li',
                        nest: () {
                          nav.element(
                            'a',
                            attributes: {'href': '$path#top'},
                            nest: _xmlText(item['label'] as String),
                          );
                          final children = (item['children'] as List)
                              .cast<Map<String, dynamic>>();
                          if (children.isNotEmpty) entries(children);
                        },
                      );
                    }
                  },
                );
              }

              entries(
                toc.isEmpty
                    ? [
                        for (final item in spine)
                          {
                            'href': {'path': item['href']},
                            'label': metadata['title'],
                            'children': <Map<String, dynamic>>[],
                          },
                      ]
                    : toc,
              );
            },
          );
        },
      );
    },
  );
  add('nav.xhtml', nav.buildDocument().toXmlString());

  Directory(directory).createSync(recursive: true);
  final temporary = Directory(directory).createTempSync('.epub-');
  try {
    final file = File(p.join(temporary.path, 'publication.epub'));
    file.writeAsBytesSync(ZipEncoder().encodeBytes(archive), flush: true);
    file.renameSync(destination.path);
  } finally {
    temporary.deleteSync(recursive: true);
  }
  return destination.path;
}

/// XML 1.0 不允许的控制字符不作为标记写入，正文保留替代字符。
String _xmlText(String text) => String.fromCharCodes(
  text.runes.map(
    (rune) =>
        rune == 9 ||
            rune == 10 ||
            rune == 13 ||
            (rune >= 0x20 && rune <= 0xD7FF) ||
            (rune >= 0xE000 && rune <= 0xFFFD) ||
            (rune >= 0x10000 && rune <= 0x10FFFF)
        ? rune
        : 0xFFFD,
  ),
);
