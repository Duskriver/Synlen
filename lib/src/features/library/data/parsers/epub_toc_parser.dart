part of 'epub_zip_parser.dart';

/// Parse NCX file for TOC navigation tree
/// Returns the pure hierarchical structure as defined in the NCX
/// No gap-filling or spine merging is performed
List<TocItem> _parseNcx(
  String content,
  Map<String, (Href, String?)> manifestMap,
  String baseDir,
  Map<String, int> spineIndexMap,
) {
  try {
    final doc = XmlDocument.parse(content);
    final navMapElement = doc.findAllElements('navMap').firstOrNull;

    if (navMapElement == null) {
      return [];
    }

    return _parseNavPoints(
      navMapElement.findElements('navPoint'),
      manifestMap,
      0,
      baseDir,
      spineIndexMap,
    );
  } catch (e) {
    return [];
  }
}

/// Parse navPoint elements recursively
/// Builds the pure hierarchical TOC tree as defined in the NCX
List<TocItem> _parseNavPoints(
  Iterable<XmlElement> navPoints,
  Map<String, (Href, String?)> manifestMap,
  int depth,
  String baseDir,
  Map<String, int> spineIndexMap,
) {
  final chapters = <TocItem>[];

  for (final navPoint in navPoints) {
    final labelElement = navPoint.findElements('navLabel').firstOrNull;
    final contentElement = navPoint.findElements('content').firstOrNull;

    if (labelElement == null || contentElement == null) {
      continue;
    }

    final label =
        labelElement.findElements('text').firstOrNull?.innerText.trim() ??
        'Chapter';
    final src = contentElement.getAttribute('src') ?? '';

    // Resolve href relative to OPF directory
    final hrefStr = _resolveRelativePath(baseDir, src);
    var href = _resolveHref(hrefStr);

    // Map to spine index for progress tracking
    int spineIdx = -1;
    if (href != null) {
      final normalizedPath = _normalizePath(href.path);
      spineIdx = spineIndexMap[normalizedPath] ?? -1;
    }

    // Parse nested children recursively
    final children = _parseNavPoints(
      navPoint.findElements('navPoint'),
      manifestMap,
      depth + 1,
      baseDir,
      spineIndexMap,
    );

    // Skip parent label if first child has the same href
    if (children.isNotEmpty && children.first.href == href) {
      href = null;
    }

    chapters.add(
      TocItem()
        ..label = label
        ..href =
            href ??
            (Href()
              ..path = ''
              ..anchor = 'top')
        ..depth = depth
        ..spineIndex = spineIdx
        ..children = children,
    );
  }

  return chapters;
}

/// Parse EPUB 3 Navigation Document (XHTML nav)
/// Returns the hierarchical TOC from <nav epub:type="toc"> ... <ol>
List<TocItem> _parseNav(
  String content,
  String baseDir,
  Map<String, int> spineIndexMap,
  String navPath,
) {
  try {
    final doc = XmlDocument.parse(content);

    final navElement = doc.findAllElements('nav').where((element) {
      final epubType =
          element.getAttribute(
            'type',
            namespaceUri: 'http://www.idpf.org/2007/ops',
          ) ??
          element.getAttribute('epub:type') ??
          element.getAttribute('type');
      return _containsWholeWord(epubType, 'toc');
    }).firstOrNull;

    if (navElement == null) {
      return [];
    }

    final rootOl = navElement.childElements
        .where((element) => element.localName == 'ol')
        .firstOrNull;

    if (rootOl == null) {
      return [];
    }

    return _parseNavListItems(
      rootOl.findElements('li'),
      0,
      baseDir,
      spineIndexMap,
      navPath,
    );
  } catch (e) {
    return [];
  }
}

/// Parse nested NAV list items recursively
List<TocItem> _parseNavListItems(
  Iterable<XmlElement> listItems,
  int depth,
  String baseDir,
  Map<String, int> spineIndexMap,
  String navPath,
) {
  final chapters = <TocItem>[];

  for (final listItem in listItems) {
    final anchorOrSpan = listItem.childElements
        .where(
          (element) => element.localName == 'a' || element.localName == 'span',
        )
        .firstOrNull;

    final label = anchorOrSpan?.innerText.trim().isNotEmpty == true
        ? anchorOrSpan!.innerText.trim()
        : 'Chapter';

    final hrefValue = anchorOrSpan?.localName == 'a'
        ? anchorOrSpan!.getAttribute('href')
        : null;

    Href? href;
    int spineIdx = -1;
    if (hrefValue != null && hrefValue.trim().isNotEmpty) {
      if (hrefValue == '#') {
        href = Href()
          ..path = navPath
          ..anchor = 'top';
      } else {
        final hrefStr = _resolveRelativePath(baseDir, hrefValue);
        href = _resolveHref(hrefStr);
        if (href != null) {
          final normalizedPath = _normalizePath(href.path);
          spineIdx = spineIndexMap[normalizedPath] ?? -1;
        }
      }
    }

    final nestedOl = listItem.childElements
        .where((element) => element.localName == 'ol')
        .firstOrNull;

    final children = nestedOl == null
        ? <TocItem>[]
        : _parseNavListItems(
            nestedOl.findElements('li'),
            depth + 1,
            baseDir,
            spineIndexMap,
            navPath,
          );

    chapters.add(
      TocItem()
        ..label = label
        ..href =
            href ??
            (Href()
              ..path = ''
              ..anchor = 'top')
        ..depth = depth
        ..spineIndex = spineIdx
        ..children = children,
    );
  }

  return chapters;
}

bool _containsWholeWord(String? value, String word) {
  if (value == null || value.trim().isEmpty) return false;
  final pattern = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false);
  return pattern.hasMatch(value);
}

/// Parse spine as flat TOC list (fallback when no NCX/NAV exists)
/// Creates simple sequential chapter entries from spine order
List<TocItem> _parseSpineAsChapters(List<SpineItem> spineItems) {
  final chapters = <TocItem>[];
  int chapterNum = 1;

  for (final spineItem in spineItems) {
    // Only include linear items in fallback TOC
    if (!spineItem.linear) continue;

    final href = Href()
      ..path = spineItem.href
      ..anchor = 'top';

    chapters.add(
      TocItem()
        ..label = 'Chapter $chapterNum'
        ..href = href
        ..depth = 0
        ..spineIndex = spineItem.index
        ..children = [],
    );
    chapterNum++;
  }

  return chapters;
}
