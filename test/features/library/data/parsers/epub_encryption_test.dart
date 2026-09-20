import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/parsers/epub_zip_parser.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

void main() {
  group('EpubZipParser encryption.xml 判定', () {
    late EpubZipParser parser;

    setUp(() {
      parser = EpubZipParser();
    });

    test('仅字体混淆（IDPF 算法 + 字体 media-type）→ 放行导入', () {
      // Arrange
      final epubBytes = _createEncryptedEpub(
        algorithm: 'http://www.idpf.org/2008/embedding',
        targetUri: 'OEBPS/fonts/serif.otf',
        targetMediaType: 'application/vnd.ms-opentype',
      );

      // Act
      final result = parser.parseFromBytes(epubBytes);

      // Assert
      expect(result.isRight(), true);
      expect(result.getRight().toNullable()!.title, 'Obfuscated Font Book');
    });

    test('仅字体混淆（Adobe 算法）→ 放行导入', () {
      // Arrange
      final epubBytes = _createEncryptedEpub(
        algorithm: 'http://ns.adobe.com/pdf/enc#RC',
        targetUri: 'OEBPS/fonts/serif.otf',
        targetMediaType: 'application/vnd.ms-opentype',
      );

      // Act
      final result = parser.parseFromBytes(epubBytes);

      // Assert
      expect(result.isRight(), true);
    });

    for (final (href, target) in [
      ('./fonts/serif.otf', 'OEBPS/fonts/serif.otf'),
      ('../fonts/serif.otf', 'fonts/serif.otf'),
      ('fonts/../serif.otf', 'OEBPS/serif.otf'),
      ('fonts/serif.otf', './OEBPS/fonts/../fonts/serif.otf'),
      ('%2e%2e/fonts/serif.otf', 'fonts/serif.otf'),
      (r'..\fonts\serif.otf', 'fonts/serif.otf'),
    ]) {
      test('字体路径 $href 与容器路径 $target 指向同一资源时放行', () {
        final result = parser.parseFromBytes(
          _createEncryptedEpub(
            algorithm: 'http://www.idpf.org/2008/embedding',
            targetUri: target,
            targetMediaType: 'font/otf',
            fontHref: href,
          ),
        );

        expect(result.isRight(), isTrue);
      });
    }

    test('CipherReference 从容器根解析，不相对于 OPF 目录', () {
      final result = parser.parseFromBytes(
        _createEncryptedEpub(
          algorithm: 'http://www.idpf.org/2008/embedding',
          targetUri: 'fonts/serif.otf',
          targetMediaType: 'font/otf',
        ),
      );

      expect(
        result.getLeft().toNullable()!.code,
        LibraryErrorCode.drmProtected,
      );
    });

    test('越过容器根的字体路径不能匹配根内资源', () {
      final result = parser.parseFromBytes(
        _createEncryptedEpub(
          algorithm: 'http://www.idpf.org/2008/embedding',
          targetUri: 'fonts/serif.otf',
          targetMediaType: 'font/otf',
          fontHref: '../../fonts/serif.otf',
        ),
      );

      expect(
        result.getLeft().toNullable()!.code,
        LibraryErrorCode.drmProtected,
      );
    });

    test('encryption.xml 含未知算法 → 拒绝且错误信息可区分', () {
      // Arrange：LCP 算法，目标仍是字体
      final epubBytes = _createEncryptedEpub(
        algorithm: 'http://readium.org/2014/01/lcp',
        targetUri: 'OEBPS/fonts/serif.otf',
        targetMediaType: 'application/vnd.ms-opentype',
      );

      // Act
      final result = parser.parseFromBytes(epubBytes);

      // Assert
      expect(result.isLeft(), true);
      final error = result.getLeft().toNullable()!;
      expect(error.code, LibraryErrorCode.drmProtected);
      expect(error.details, contains('unsupported encryption algorithm'));
    });

    test('encryption.xml 加密了 xhtml 内容文档 → 拒绝', () {
      // Arrange：算法是 IDPF 但目标是内容文档
      final epubBytes = _createEncryptedEpub(
        algorithm: 'http://www.idpf.org/2008/embedding',
        targetUri: 'OEBPS/chapter0.xhtml',
        targetMediaType: 'application/xhtml+xml',
      );

      // Act
      final result = parser.parseFromBytes(epubBytes);

      // Assert
      expect(result.isLeft(), true);
      final error = result.getLeft().toNullable()!;
      expect(error.code, LibraryErrorCode.drmProtected);
      expect(error.details, contains('not a font'));
    });

    test('encryption.xml 不可解析 → 拒绝（无法证明仅字体混淆）', () {
      // Arrange
      final epubBytes = _createEncryptedEpub(
        algorithm: 'http://www.idpf.org/2008/embedding',
        targetUri: 'OEBPS/fonts/serif.otf',
        targetMediaType: 'application/vnd.ms-opentype',
        rawEncryptionXml: '<encryption><broken',
      );

      // Act
      final result = parser.parseFromBytes(epubBytes);

      // Assert
      expect(result.isLeft(), true);
      expect(
        result.getLeft().toNullable()!.code,
        LibraryErrorCode.drmProtected,
      );
    });
  });
}

// ==================== Helper Functions ====================

/// 构造含 encryption.xml 的最小 EPUB 字节流。
///
/// [rawEncryptionXml] 用于注入畸形清单；默认按 [algorithm] / [targetUri] 生成。
Uint8List _createEncryptedEpub({
  required String algorithm,
  required String targetUri,
  required String targetMediaType,
  String fontHref = 'fonts/serif.otf',
  String? rawEncryptionXml,
}) {
  final archive = Archive();

  final mimetype = 'application/epub+zip';
  archive.addFile(ArchiveFile('mimetype', mimetype.length, mimetype.codeUnits));

  final containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  archive.addFile(
    ArchiveFile(
      'META-INF/container.xml',
      containerXml.length,
      containerXml.codeUnits,
    ),
  );

  final encryptionXml =
      rawEncryptionXml ??
      '''<?xml version="1.0"?>
<encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <enc:EncryptedData xmlns:enc="http://www.w3.org/2001/04/xmlenc#">
    <enc:EncryptionMethod Algorithm="$algorithm"/>
    <enc:CipherData>
      <enc:CipherReference URI="$targetUri"/>
    </enc:CipherData>
  </enc:EncryptedData>
</encryption>''';
  archive.addFile(
    ArchiveFile(
      'META-INF/encryption.xml',
      encryptionXml.length,
      encryptionXml.codeUnits,
    ),
  );

  final opfContent =
      '''<?xml version="1.0"?>
<package version="3.0" unique-identifier="book-id" xmlns="http://www.idpf.org/2007/opf">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="book-id">urn:uuid:9c6f6f34-2f0c-4b32-9e60-5f05e8c1a2b3</dc:identifier>
    <dc:title>Obfuscated Font Book</dc:title>
    <dc:creator>Test Author</dc:creator>
  </metadata>
  <manifest>
    <item id="chapter0" href="chapter0.xhtml" media-type="application/xhtml+xml"/>
    <item id="font1" href="$fontHref" media-type="$targetMediaType"/>
  </manifest>
  <spine>
    <itemref idref="chapter0"/>
  </spine>
</package>''';
  archive.addFile(
    ArchiveFile('OEBPS/content.opf', opfContent.length, opfContent.codeUnits),
  );

  final chapterContent = '''<?xml version="1.0"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body><h1>Chapter 1</h1></body>
</html>''';
  archive.addFile(
    ArchiveFile(
      'OEBPS/chapter0.xhtml',
      chapterContent.length,
      chapterContent.codeUnits,
    ),
  );

  // 字体条目（内容是混淆字节对导入判定无影响，仅占位）
  archive.addFile(ArchiveFile('OEBPS/fonts/serif.otf', 4, [0, 1, 2, 3]));

  final zipEncoder = ZipEncoder();
  return Uint8List.fromList(zipEncoder.encode(archive));
}
