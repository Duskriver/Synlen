import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../../core/file_handling/backup_archive_extractor.dart';

/// 书内脚本不能进入拥有应用桥接能力的原生 WebView。
/// 无活动内容时保留原包；需要净化时生成保留路径、标识符和字体字节的副本。
class ReadiumEpubPublicationCache {
  ReadiumEpubPublicationCache({required this.cacheDirectory});

  final String cacheDirectory;
  final Map<String, Future<String>> _pending = {};

  Future<String> prepare(String sourcePath) {
    final directory = cacheDirectory;
    return _pending.putIfAbsent(
      sourcePath,
      () => Isolate.run(() => _prepare(sourcePath, directory)).whenComplete(() {
        _pending.remove(sourcePath);
      }),
    );
  }
}

Future<String> _prepare(String sourcePath, String cacheDirectory) async {
  final source = File(sourcePath);
  final before = await source.stat();
  final digest = await sha256.bind(source.openRead()).first;
  // 净化规则改变时递增版本，旧的通过标记和副本均失效。
  final key = 'epub-v1-$digest';
  final clean = File(p.join(cacheDirectory, '$key.clean'));
  final prepared = File(p.join(cacheDirectory, '$key.epub'));
  if (await clean.exists() && await clean.readAsString() == 'clean') {
    return sourcePath;
  }
  if (await prepared.exists() && await prepared.length() > 0) {
    return prepared.path;
  }

  await Directory(cacheDirectory).create(recursive: true);
  final temporary = await Directory(cacheDirectory).createTemp('.prepare-');
  try {
    final names = _entryNames(source);
    final extracted = Directory(p.join(temporary.path, 'content'));
    // archive 4.3 的 decodeBytes(verify: true) 不校验 CRC；复用逐条真实校验。
    await extractVerifiedBackupZip(source, extracted);
    final documents = _contentDocuments(extracted, names);
    var changed = false;
    for (final path in documents) {
      final file = File(p.join(extracted.path, path));
      final document = _readXml(file);
      if (_stripActiveContent(document)) {
        for (final declaration
            in document.children.whereType<XmlDeclaration>()) {
          declaration.encoding = 'UTF-8';
        }
        await file.writeAsString(document.toXmlString());
        changed = true;
      }
    }
    final after = await source.stat();
    if (before.size != after.size || before.modified != after.modified) {
      throw StateError('准备阅读文件时 EPUB 源文件发生变化');
    }
    if (!changed) {
      final marker = File(p.join(temporary.path, 'clean'));
      await marker.writeAsString('clean', flush: true);
      await marker.rename(clean.path);
      return sourcePath;
    }

    final output = File(p.join(temporary.path, 'prepared.epub'));
    final encoder = ZipFileEncoder()..create(output.path);
    try {
      final mime = await File(p.join(extracted.path, 'mimetype')).readAsBytes();
      encoder.addArchiveFile(
        ArchiveFile.noCompress('mimetype', mime.length, mime),
      );
      for (final name in names.where((name) => name != 'mimetype')) {
        if (name.endsWith('/')) {
          encoder.addArchiveFile(ArchiveFile.directory(name));
        } else {
          await encoder.addFile(File(p.join(extracted.path, name)), name);
        }
      }
    } finally {
      await encoder.close();
    }
    await output.rename(prepared.path);
    return prepared.path;
  } finally {
    await temporary.delete(recursive: true);
  }
}

/// 重名或非规范路径会让扫描器与原生阅读器选中不同条目，必须拒绝。
List<String> _entryNames(File source) {
  final input = InputFileStream(source.path);
  try {
    final directory = ZipDirectory()..read(input);
    final names = <String>[];
    final canonical = <String>{};
    for (final header in directory.fileHeaders) {
      final name = header.filename;
      final normalized = p.posix.normalize(name);
      if (name.contains('\\') ||
          (name.endsWith('/') ? '$normalized/' : normalized) != name ||
          !canonical.add(normalized)) {
        throw const FormatException('EPUB 包含歧义路径');
      }
      names.add(name);
    }
    if (!names.contains('mimetype') ||
        !names.contains('META-INF/container.xml')) {
      throw const FormatException('EPUB 缺少包声明');
    }
    return names;
  } finally {
    input.closeSync();
  }
}

Set<String> _contentDocuments(Directory extracted, List<String> names) {
  final paths = names
      .where(
        (name) => const {
          '.xhtml',
          '.html',
          '.htm',
          '.xht',
          '.svg',
        }.contains(p.posix.extension(name).toLowerCase()),
      )
      .toSet();
  final container = _readXml(
    File(p.join(extracted.path, 'META-INF/container.xml')),
  );
  final roots = container.descendants.whereType<XmlElement>().where(
    (element) => element.localName == 'rootfile',
  );
  if (roots.isEmpty) throw const FormatException('EPUB 缺少 OPF 路径');
  for (final root in roots) {
    final packagePath = _resolveEntry('', root.getAttribute('full-path') ?? '');
    if (!names.contains(packagePath)) throw const FormatException('EPUB 清单不存在');
    final package = _readXml(File(p.join(extracted.path, packagePath)));
    for (final item in package.descendants.whereType<XmlElement>().where(
      (element) => element.localName == 'item',
    )) {
      if (!const {
        'application/xhtml+xml',
        'text/html',
        'image/svg+xml',
        'application/xml',
        'text/xml',
      }.contains(item.getAttribute('media-type'))) {
        continue;
      }
      final path = _resolveEntry(
        p.posix.dirname(packagePath),
        item.getAttribute('href') ?? '',
      );
      if (!names.contains(path)) throw const FormatException('EPUB 正文资源不存在');
      paths.add(path);
    }
  }
  return paths;
}

String _resolveEntry(String base, String href) {
  final uri = Uri.parse(href);
  if (href.isEmpty ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.startsWith('/')) {
    throw const FormatException('EPUB 正文必须引用包内文件');
  }
  final path = p.posix.normalize(
    p.posix.join(base, Uri.decodeComponent(uri.path)),
  );
  if (path == '..' || path.startsWith('../')) {
    throw const FormatException('EPUB 正文路径越界');
  }
  return path;
}

XmlDocument _readXml(File file) {
  final bytes = file.readAsBytesSync();
  String source;
  final utf16 =
      bytes.length >= 2 &&
      ((bytes[0] == 0xff && bytes[1] == 0xfe) ||
          (bytes[0] == 0xfe && bytes[1] == 0xff));
  if (utf16) {
    if (bytes.length.isOdd) throw const FormatException('无效的 UTF-16 XML');
    final little = bytes[0] == 0xff;
    source = String.fromCharCodes([
      for (var i = 2; i < bytes.length; i += 2)
        little
            ? bytes[i] | (bytes[i + 1] << 8)
            : (bytes[i] << 8) | bytes[i + 1],
    ]);
  } else {
    source = utf8.decode(bytes);
  }
  final document = XmlDocument.parse(
    source,
    entityMapping: const XmlDefaultEntityMapping.html5(),
  );
  // 不展开书籍自定义实体，避免解析器与 WebKit 的 DTD 解释不同。
  if (document.children.whereType<XmlDoctype>().any(
    (node) => node.internalSubset?.trim().isNotEmpty ?? false,
  )) {
    throw const FormatException('阅读内容不支持自定义 DTD 实体');
  }
  return document;
}

bool _stripActiveContent(XmlDocument document) {
  var changed = false;
  for (final instruction
      in document.descendants.whereType<XmlProcessing>().toList()) {
    if (instruction.target.toLowerCase() == 'xml-stylesheet') {
      instruction.parent?.children.remove(instruction);
      changed = true;
    }
  }
  for (final element in document.descendants.whereType<XmlElement>().toList()) {
    final name = element.localName.toLowerCase();
    final attributeName = element.getAttribute('attributeName')?.toLowerCase();
    if (const {'script', 'iframe', 'object', 'embed'}.contains(name) ||
        (name == 'meta' &&
            element.getAttribute('http-equiv')?.toLowerCase() == 'refresh') ||
        (const {'animate', 'set'}.contains(name) &&
            (attributeName?.startsWith('on') == true ||
                const {'href', 'xlink:href'}.contains(attributeName)))) {
      if (element.parent == document) {
        throw const FormatException('书籍正文根节点是活动内容');
      }
      element.parent?.children.remove(element);
      changed = true;
      continue;
    }
    for (final attribute in element.attributes.toList()) {
      if (attribute.name.prefix == 'xmlns' ||
          attribute.name.qualified == 'xmlns') {
        continue;
      }
      final local = attribute.localName.toLowerCase();
      final url = attribute.value
          .replaceAll(RegExp(r'[\x00-\x20\x7f]'), '')
          .toLowerCase();
      if (local.startsWith('on') ||
          local == 'srcdoc' ||
          (const {
                'href',
                'src',
                'action',
                'formaction',
                'data',
              }.contains(local) &&
              (url.startsWith('javascript:') ||
                  url.startsWith('vbscript:') ||
                  url.startsWith('data:text/html') ||
                  url.startsWith('data:application/xhtml+xml')))) {
        element.attributes.remove(attribute);
        changed = true;
      }
    }
  }
  return changed;
}
