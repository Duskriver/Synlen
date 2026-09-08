import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:fpdart/fpdart.dart';
import '../../domain/book_manifest.dart';

/// Parser that reads EPUB structure directly from ZIP archive
/// No full extraction required - reads specific files in-memory
part 'epub_opf_metadata.dart';
part 'epub_toc_parser.dart';
part 'epub_path_resolver.dart';

class EpubZipParser {
  /// Parse EPUB from file path
  Future<Either<String, EpubZipParseResult>> parseFromFile(
    String filePath, {
    String? fileName,
  }) async {
    try {
      final inputStream = InputFileStream(filePath);
      final archive = ZipDecoder().decodeStream(inputStream);
      return parseFromArchive(archive, fileName: fileName);
    } catch (e) {
      return left('Failed to read file: $e');
    }
  }

  Either<String, EpubZipParseResult> parseFromBytes(
    List<int> bytes, {
    String? fileName,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      return parseFromArchive(archive, fileName: fileName);
    } catch (e) {
      return left('Failed to read bytes: $e');
    }
  }

  /// Parse EPUB from bytes
  Either<String, EpubZipParseResult> parseFromArchive(
    Archive archive, {
    String? fileName,
  }) {
    try {
      // Find META-INF/encryption.xml to check if the EPUB is encrypted
      final encryptionFile = archive.findFile('META-INF/encryption.xml');
      if (encryptionFile != null) {
        return left('Encrypted EPUBs are not supported');
      }

      // Step 1: Find OPF file path
      final opfPathResult = _findOpfPath(archive);
      if (opfPathResult.isLeft()) {
        return left(opfPathResult.getLeft().toNullable()!);
      }
      final opfPath = opfPathResult.getRight().toNullable()!;

      // Step 2: Read OPF file content
      final opfFile = archive.findFile(opfPath);
      if (opfFile == null) {
        return left('OPF file not found in archive');
      }
      final opfContent = _decodeString(opfFile.content as List<int>);

      // Step 3: Parse OPF XML
      final parseResult = _parseOpf(opfContent, opfPath, archive, fileName);
      return parseResult;
    } catch (e) {
      return left('Parse error: $e');
    }
  }

  /// Find OPF file path in the archive
  Either<String, String> _findOpfPath(Archive archive) {
    try {
      // Strategy 1: Parse container.xml (standard EPUB structure)
      final containerFile = archive.findFile('META-INF/container.xml');
      if (containerFile != null) {
        final containerContent = _decodeString(
          containerFile.content as List<int>,
        );
        final containerDoc = XmlDocument.parse(containerContent);

        final rootFileElement = containerDoc
            .findAllElements('rootfile')
            .firstOrNull;

        if (rootFileElement != null) {
          final fullPath = rootFileElement.getAttribute('full-path');
          if (fullPath != null) {
            return right(fullPath);
          }
        }
      }

      // Strategy 2: Check common locations
      final commonPaths = [
        'content.opf',
        'OEBPS/content.opf',
        'OPS/content.opf',
        'EPUB/content.opf',
      ];

      for (final path in commonPaths) {
        if (archive.findFile(path) != null) {
          return right(path);
        }
      }

      // Strategy 3: Scan for .opf files
      for (final file in archive.files) {
        if (file.name.endsWith('.opf')) {
          return right(file.name);
        }
      }

      return left('OPF file not found');
    } catch (e) {
      return left('Error finding OPF: $e');
    }
  }

  /// Parse OPF file content
  static Either<String, EpubZipParseResult> _parseOpf(
    String content,
    String opfPath,
    Archive archive,
    String? fileName,
  ) {
    try {
      final opfDir = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/'))
          : '';

      final doc = XmlDocument.parse(content);
      final packageElement = doc.rootElement;

      // Extract version
      final version = packageElement.getAttribute('version') ?? '2.0';

      // Parse metadata
      final metadataElement = packageElement
          .findElements('metadata')
          .firstOrNull;
      if (metadataElement == null) {
        return left('Metadata element not found');
      }

      // Parse spine for chapter order
      final spineElement = packageElement.findElements('spine').firstOrNull;
      final manifestElement = packageElement
          .findElements('manifest')
          .firstOrNull;

      final directionStr =
          spineElement?.getAttribute('page-progression-direction') ?? 'ltr';
      int direction = 0; // Default to LTR
      if (directionStr.toLowerCase() == 'rtl') {
        direction = 1;
      }

      if (spineElement == null || manifestElement == null) {
        return left('Spine or manifest element not found');
      }

      // Build manifest map (id -> (href, properties))
      final manifestMap = <String, (Href, String?)>{};
      for (final item in manifestElement.findElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        final properties = item.getAttribute('properties');
        if (id != null && href != null) {
          manifestMap[id] = (_resolveHref(href)!, properties);
        }
      }

      final guideElement = packageElement.findElements('guide').firstOrNull;
      final guideItems = _parseGuide(guideElement);

      var metadata = _parseMetadata(
        metadataElement,
        manifestMap,
        guideItems,
        version,
        opfDir,
        fileName,
        archive,
      );

      // Step 1: Build spine list with full metadata
      final spineItems = <SpineItem>[];
      final spineIndexMap = <String, int>{}; // path -> index for TOC mapping
      int index = 0;

      for (final itemref in spineElement.findElements('itemref')) {
        final idref = itemref.getAttribute('idref');
        final linearAttr = itemref.getAttribute('linear');
        final isLinear = linearAttr == null || linearAttr.toLowerCase() != 'no';
        final properties = itemref.getAttribute('properties');

        if (idref != null && manifestMap.containsKey(idref)) {
          final href = manifestMap[idref]!.$1;
          final resolvedPath = _normalizePath(
            opfDir.isEmpty ? href.path : '$opfDir/${href.path}',
          );

          spineItems.add(
            SpineItem(
              index: index,
              href: resolvedPath,
              idref: idref,
              linear: isLinear,
              properties: properties,
            ),
          );

          spineIndexMap[resolvedPath] = index;
          index++;
        }
      }

      // Step 2: Parse TOC structure (NAV first, then NCX)
      List<TocItem> toc = [];

      // EPUB 3 NAV document: manifest item with properties containing whole word "nav"
      String? navPath;
      for (final entry in manifestMap.entries) {
        final properties = entry.value.$2;
        if (_containsWholeWord(properties, 'nav')) {
          final navHref = entry.value.$1;
          navPath = opfDir.isEmpty ? navHref.path : '$opfDir/${navHref.path}';
          break;
        }
      }

      if (navPath != null) {
        final navFile = archive.findFile(navPath);
        if (navFile != null) {
          final navContent = _decodeString(navFile.content as List<int>);

          // Extract NAV directory for resolving relative links in NAV parsing
          final navDir = navPath.contains('/')
              ? navPath.substring(0, navPath.lastIndexOf('/'))
              : '';
          toc = _parseNav(navContent, navDir, spineIndexMap, navPath);
        }
      }

      // EPUB 2 NCX fallback
      if (toc.isEmpty) {
        final tocId = spineElement.getAttribute('toc');
        if (tocId != null && manifestMap.containsKey(tocId)) {
          final tocHref = manifestMap[tocId]!.$1;
          final tocPath = opfDir.isEmpty
              ? tocHref.path
              : '$opfDir/${tocHref.path}';
          final tocFile = archive.findFile(tocPath);

          if (tocFile != null) {
            final tocContent = _decodeString(tocFile.content as List<int>);

            // Extract TOC directory for resolving relative links in NCX parsing
            final ncxDir = tocPath.contains('/')
                ? tocPath.substring(0, tocPath.lastIndexOf('/'))
                : '';
            toc = _parseNcx(tocContent, manifestMap, ncxDir, spineIndexMap);
          }
        }
      }

      // Fallback: Create flat TOC from spine if no NCX/NAV found
      if (toc.isEmpty) {
        toc = _parseSpineAsChapters(spineItems);
      }

      // Generate id for each TocItem
      int tocIdCounter = 0;
      void assignTocIds(TocItem item, [int parentId = -1]) {
        item.id = tocIdCounter++;
        item.parentId = parentId;
        for (final child in item.children) {
          assignTocIds(child, item.id);
        }
      }

      for (final item in toc) {
        assignTocIds(item);
      }

      final result = EpubZipParseResult(
        title: metadata.title,
        author: metadata.author,
        authors: metadata.authors,
        description: metadata.description,
        subjects: metadata.subjects,
        coverHref: metadata.coverHref,
        opfRootPath: opfPath,
        epubVersion: version,
        totalChapters: toc.expand((item) => item.flatten()).length,
        spine: spineItems,
        toc: toc,
        manifestItems: manifestMap.entries
            .map(
              (e) => ManifestItem()
                ..id = e.key
                ..href = e.value.$1
                ..properties = e.value.$2
                ..mediaType = 'application/xhtml+xml',
            )
            .toList(),
        readDirection: direction,
      );

      return right(result);
    } catch (e) {
      return left('OPF parse error: $e');
    }
  }
}

class EpubZipParseResult {
  final String title;
  final String author;
  final List<String> authors;
  final String? description;
  final List<String> subjects;
  final String? coverHref;
  final String opfRootPath;
  final String epubVersion;
  final int totalChapters;
  final List<SpineItem> spine;
  final List<TocItem> toc;
  final List<ManifestItem> manifestItems;
  final int readDirection;

  EpubZipParseResult({
    required this.title,
    required this.author,
    required this.authors,
    this.description,
    required this.subjects,
    this.coverHref,
    required this.opfRootPath,
    required this.epubVersion,
    required this.totalChapters,
    required this.spine,
    required this.toc,
    required this.manifestItems,
    required this.readDirection,
  });
}

String _decodeString(List<int> bytes) {
  String decodedString;
  try {
    decodedString = utf8.decode(bytes);
  } catch (e) {
    throw FormatException('cannot decode string as UTF-8: $e');
  }
  return decodedString;
}
