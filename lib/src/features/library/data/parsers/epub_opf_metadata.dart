part of 'epub_zip_parser.dart';

/// Parse metadata element
_MetadataResult _parseMetadata(
  XmlElement metadataElement,
  Map<String, (Href, String?)> manifestMap,
  List<_GuideItem> guideItems,
  String version,
  String opfDir,
  String? fileName,
  Archive archive,
) {
  // Helper function to find elements by local name (ignoring namespace prefix)
  // This handles both <title> and <dc:title> formats
  Iterable<XmlElement> findByLocalName(String name) {
    return metadataElement.descendantElements.where((e) => e.localName == name);
  }

  // Extract titles
  var titles = findByLocalName(
    'title',
  ).map((e) => e.innerText.trim()).where((t) => t.isNotEmpty).toList();
  if (titles.isEmpty) {
    // Fallback to file name without extension
    final fallbackTitle = fileName != null
        ? fileName.split('/').last.split('.').first
        : 'Unknown Title';
    titles = [fallbackTitle];
  }

  // Extract authors (dc:creator)
  final authors = findByLocalName(
    'creator',
  ).map((e) => e.innerText.trim()).where((a) => a.isNotEmpty).toList();

  // Extract description
  final description = findByLocalName(
    'description',
  ).firstOrNull?.innerText.trim();

  // Extract subjects
  final subjects = findByLocalName(
    'subject',
  ).map((e) => e.innerText.trim()).where((s) => s.isNotEmpty).toList();

  // Extract cover (from meta tag with name="cover")
  String? coverHref;
  final coverMeta = metadataElement
      .findAllElements('meta')
      .where((e) => e.getAttribute('name') == 'cover')
      .firstOrNull;

  if (coverMeta != null) {
    final coverId = coverMeta.getAttribute('content');
    if (coverId != null) {
      if (manifestMap.containsKey(coverId)) {
        coverHref = manifestMap[coverId]!.$1.path;
      }
    }
  }

  if (coverHref == null || !_isWellImageFile(coverHref)) {
    // For EPUB 3, also check for manifest item with properties containing whole word "cover-image"
    for (final entry in manifestMap.entries) {
      final properties = entry.value.$2;
      if (_containsWholeWord(properties, 'cover-image')) {
        coverHref = entry.value.$1.path;
        break;
      }
    }
  }

  // Return cover href relative to OPF directory
  String? extractCoverHrefFromGuideItem(_GuideItem item) {
    final href = _resolveRelativePath(opfDir, item.href);
    String? resultHref;

    // href could be a xhtml file - we need to find the actual image file it references
    if (href.endsWith('.xhtml') ||
        href.endsWith('.html') ||
        href.endsWith('.htm')) {
      final coverFile = archive.findFile(href);
      if (coverFile != null) {
        final coverContent = _decodeString(coverFile.content as List<int>);
        final imgSrc = _extractFirstImageFromHtml(coverContent);
        if (imgSrc != null) {
          final hrefDir = href.contains('/')
              ? href.substring(0, href.lastIndexOf('/'))
              : '';
          resultHref = _resolveRelativePath(hrefDir, imgSrc);
          resultHref = _generateRelativePath(opfDir, resultHref);
        }
      }
    } else if (href.endsWith('.jpg') ||
        href.endsWith('.jpeg') ||
        href.endsWith('.png') ||
        href.endsWith('.webp')) {
      resultHref = href;
    }
    return resultHref;
  }

  if (coverHref == null || !_isWellImageFile(coverHref)) {
    // For EPUB 3, also check guide for reference with type="cover"
    final coverReference = guideItems
        .where((item) => item.type.toLowerCase() == 'cover')
        .firstOrNull;
    if (coverReference != null) {
      coverHref = extractCoverHrefFromGuideItem(coverReference);
    }
  }

  if (coverHref == null || !_isWellImageFile(coverHref)) {
    // For EPUB 2, also check guide for reference with title containing "cover"
    final coverReference = guideItems
        .where((item) => item.title.toLowerCase().contains('cover'))
        .firstOrNull;
    if (coverReference != null) {
      coverHref = extractCoverHrefFromGuideItem(coverReference);
    }
  }

  if (coverHref == null || !_isWellImageFile(coverHref)) {
    // Fallback: look for common cover file names in manifest
    for (final key in manifestMap.keys) {
      final lowerCaseKey = key.toLowerCase();
      if (lowerCaseKey == 'cover.jpg' ||
          lowerCaseKey == 'cover.png' ||
          lowerCaseKey == 'cover.jpeg' ||
          lowerCaseKey == 'cover.webp') {
        coverHref = manifestMap[key]!.$1.path;
        break;
      }
    }
  }

  return _MetadataResult(
    title: titles.firstOrNull ?? '',
    author: authors.firstOrNull ?? '',
    authors: authors,
    description: description,
    subjects: subjects,
    coverHref: coverHref,
  );
}

String? _extractFirstImageFromHtml(String htmlContent) {
  final imgRegExp = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);
  final svgImageRegExp = RegExp(
    r'<image[^>]+(?:xlink:href|href)="([^">]+)"',
    caseSensitive: false,
  );

  final imgMatch = imgRegExp.firstMatch(htmlContent);
  if (imgMatch != null && imgMatch.groupCount >= 1) {
    return imgMatch.group(1);
  }

  final svgMatch = svgImageRegExp.firstMatch(htmlContent);
  if (svgMatch != null && svgMatch.groupCount >= 1) {
    return svgMatch.group(1);
  }

  return null;
}

List<_GuideItem> _parseGuide(XmlElement? guideElement) {
  if (guideElement == null) return [];

  final guideItems = <_GuideItem>[];
  for (final reference in guideElement.findElements('reference')) {
    final type = reference.getAttribute('type') ?? '';
    final title = reference.getAttribute('title') ?? '';
    final href = reference.getAttribute('href') ?? '';
    guideItems.add(_GuideItem(type: type, title: title, href: href));
  }

  return guideItems;
}

class _MetadataResult {
  final String title;
  final String author;
  final List<String> authors;
  final String? description;
  final List<String> subjects;
  final String? coverHref;

  _MetadataResult({
    required this.title,
    required this.author,
    required this.authors,
    this.description,
    required this.subjects,
    this.coverHref,
  });
}

class _GuideItem {
  String type;
  String title;
  String href;

  _GuideItem({required this.type, required this.title, required this.href});
}
