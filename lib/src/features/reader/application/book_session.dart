import '../../library/domain/book_manifest.dart';
import '../../library/domain/book_views.dart';
import '../../library/application/book_queries.dart';
import 'book_webview_handler.dart';
import '../domain/reading_progress.dart';

/// Manages the current reading session including book data, manifest, and TOC state
class BookSession {
  ReaderBookView? _book;
  ReaderManifestView? _manifest;

  // TOC Synchronization: Pre-calculated lookup maps
  final Map<String, List<String>> _spineToAnchorsMap = {};
  final List<TocItem> _tocItemFallback = [];
  final List<TocItem> _flatToc = [];
  final Map<Href, int> _hrefToTocIndexMap = {};
  Set<String> _activeAnchors = {};

  final String fileHash;
  final BookQueries _queries;
  final List<SpineItem> _spine = [];
  final List<SpineItem> _noLinearSpine = [];

  BookSession({required this.fileHash, required BookQueries queries})
    : _queries = queries;

  // Getters
  ReaderBookView? get book => _book;
  ReaderManifestView? get manifest => _manifest;
  List<SpineItem> get spine => _spine;
  List<SpineItem> get noLinearSpine => _noLinearSpine;
  List<TocItem> get toc => _manifest?.toc ?? [];
  Set<String> get activeAnchors => _activeAnchors;
  bool get isLoaded => _book != null && _manifest != null;
  int get direction => _book?.direction ?? 0;

  /// Load book and manifest views from the library seam
  Future<bool> loadBook() async {
    // Load book view
    final book = await _queries.findBook(fileHash);
    if (book == null) {
      return false;
    }

    // Load manifest view
    final manifest = await _queries.findManifest(fileHash);
    if (manifest == null) {
      return false;
    }

    _book = book;
    _manifest = manifest;

    // filter out spine with linear=no
    _spine.clear();
    _noLinearSpine.clear();
    for (final item in manifest.spine) {
      if (item.linear) {
        _spine.add(item);
      } else {
        _noLinearSpine.add(item);
      }
    }

    // Pre-calculate TOC lookup maps for O(1) synchronization
    _buildTocLookupMaps();

    return true;
  }

  /// Pre-calculate TOC lookup maps for efficient synchronization
  void _buildTocLookupMaps() {
    if (_manifest == null || _book == null) return;

    _flatToc.clear();
    _hrefToTocIndexMap.clear();
    _spineToAnchorsMap.clear();

    void processItem(TocItem item) {
      item.id = _flatToc.length;
      _flatToc.add(item);
      _hrefToTocIndexMap[item.href] = item.id;

      final filePath = item.href.path;
      final anchorId = item.href.anchor;
      _spineToAnchorsMap.putIfAbsent(filePath, () => []).add(anchorId);

      for (final child in item.children) {
        processItem(child);
      }
    }

    for (final item in _manifest!.toc) {
      processItem(item);
    }

    TocItem toc = TocItem()
      ..label = _book!.title
      ..href = (Href()
        ..path = ''
        ..anchor = 'top')
      ..id = -1;
    _tocItemFallback.clear();
    for (final spineItem in _spine) {
      final anchors = _spineToAnchorsMap[spineItem.href] ?? [];
      _tocItemFallback.add(toc);
      if (anchors.isNotEmpty) {
        final lastHref = Href()
          ..path = spineItem.href
          ..anchor = anchors.last;
        toc = _hrefToTocIndexMap[lastHref] != null
            ? _flatToc[_hrefToTocIndexMap[lastHref]!]
            : toc;
      }
    }
  }

  /// 完整位置直接落库；未加载、无效位置和写入失败均交由调用者处理。
  Future<void> saveProgress(ReadingProgress position) async {
    if (!isLoaded) throw StateError('书籍尚未加载');
    if (position.chapterIndex < 0 ||
        position.chapterIndex >= _spine.length ||
        position.pageCount <= 0 ||
        position.pageIndex < 0 ||
        position.pageIndex >= position.pageCount) {
      throw ArgumentError.value(position, 'position', '无效的阅读位置');
    }
    await _queries.saveProgress(
      bookId: _book!.id,
      chapterIndex: position.chapterIndex,
      progress:
          (position.chapterIndex +
              (position.pageIndex + 1) / position.pageCount) /
          _spine.length,
      scrollPosition: position.pageIndex / position.pageCount,
    );
  }

  /// Get anchors for a spine path as JSON array string
  List<String> getAnchorsForSpine(String spinePath) {
    return _spineToAnchorsMap[spinePath] ?? [];
  }

  String? getSpineProperties(int index) {
    if (index < 0 || index >= _spine.length) return null;
    return _spine[index].properties;
  }

  /// Update active anchors based on scroll position
  void updateActiveAnchors(List<String> anchorIds) {
    _activeAnchors = anchorIds.toSet();
  }

  /// Generate activated href keys from current spine item and active anchors
  Set<Href> generateActivatedHrefKeys(int currentSpineItemIndex) {
    if (_manifest == null || currentSpineItemIndex >= _spine.length) {
      return {};
    }

    final path = _spine[currentSpineItemIndex].href;
    return _activeAnchors
        .map(
          (anchor) => Href()
            ..path = path
            ..anchor = anchor,
        )
        .toSet();
  }

  /// Resolve active TOC items by matching active anchors
  Set<TocItem> resolveActiveItems(int currentSpineItemIndex) {
    final activeHrefKeys = generateActivatedHrefKeys(currentSpineItemIndex);
    final activeItems = activeHrefKeys
        .map((href) {
          final tocIndex = _hrefToTocIndexMap[href];
          if (tocIndex != null && tocIndex >= 0 && tocIndex < _flatToc.length) {
            return _flatToc[tocIndex];
          } else {
            return null;
          }
        })
        .whereType<TocItem>()
        .toSet();

    if (activeItems.isEmpty &&
        _tocItemFallback.isNotEmpty &&
        currentSpineItemIndex < _tocItemFallback.length) {
      activeItems.add(_tocItemFallback[currentSpineItemIndex]);
    }
    return activeItems;
  }

  /// Find first valid href in a TOC item or its children
  Href? findFirstValidHref(TocItem item) {
    if (item.href.path.isNotEmpty) {
      return item.href;
    }

    if (item.children.isNotEmpty) {
      for (final child in item.children) {
        final found = findFirstValidHref(child);
        if (found != null) {
          return found;
        }
      }
    }

    return null;
  }

  /// Get URL for a spine item with optional anchor
  String getSpineItemUrl(int index, [String anchor = 'top']) {
    if (_manifest == null || index >= _spine.length) {
      return '';
    }

    final href = Href()
      ..path = _spine[index].href
      ..anchor = anchor;
    return BookWebViewHandler.getFileUrl(fileHash, href);
  }

  /// Find spine index for a TOC item
  int? findSpineIndexForTocItem(TocItem item) {
    final targetHref = findFirstValidHref(item);
    if (targetHref == null || _manifest == null) {
      return null;
    }

    final index = _spine.indexWhere((s) => s.href == targetHref.path);
    return index != -1 ? index : null;
  }

  int? findSpineIndexByUrl(String url) {
    if (_manifest == null) return null;

    // Check if URL is full url with book://localhost/book/{fileHash}/path(#anchor)
    // If so, extract the path, no need to extract anchor because spine only cares about path
    String path;
    if (url.startsWith(BookWebViewHandler.virtualScheme)) {
      final uri = Uri.parse(url);
      path = uri.pathSegments.skip(2).join('/'); // Skip 'book' and '{fileHash}'
    } else {
      // Otherwise, treat it as a relative path (e.g. from TOC)
      path = url.split('#')[0];
    }

    final index = _spine.indexWhere((s) => s.href == path);
    if (index != -1) {
      return index;
    }

    return null;
  }

  /// Get initial reading position
  int get initialChapterIndex => _book?.currentChapterIndex ?? 0;
  double? get initialScrollPosition => _book?.chapterScrollPosition;
}
