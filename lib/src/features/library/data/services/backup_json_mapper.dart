import 'package:synlen/src/core/database/app_database.dart';

import '../../domain/book_format.dart';
import '../../domain/book_progress.dart';
import '../../domain/book_manifest.dart';

/// 备份 JSON 到领域对象的反序列化。
///
/// 所有函数都是纯函数：\`id\` 一律置 0，由 drift 落库时分配；设备相关路径
/// （filePath / coverPath）由调用方注入，不取自 JSON。
// ---------------------------------------------------------------------------
// Reverse-mapping helpers (JSON → domain objects)
// ---------------------------------------------------------------------------

/// Deserialises a [ShelfGroup] from its JSON map.
/// The `id` field is intentionally 0 — drift assigns it on insert, and the
/// merge logic preserves the existing row if the group already exists.
ShelfGroup mapToShelfGroup(Map<String, dynamic> m) {
  return ShelfGroup(
    id: 0,
    name: m['name'] as String,
    creationDate: m['creationDate'] as int,
    updatedAt: m['updatedAt'] as int,
    isDeleted: m['isDeleted'] as bool? ?? false,
  );
}

/// Deserialises a [ShelfBook] from its JSON map.
///
/// [filePath] and [coverPath] are injected from the just-copied files rather
/// than taken from JSON, because the JSON deliberately excludes them (they
/// are device-specific absolute paths).
ShelfBook mapToShelfBook(
  Map<String, dynamic> m, {
  required String? filePath,
  required String? coverPath,
  required BookFormat format,
}) {
  final progress = m['progress'] == null
      ? null
      : BookProgress.fromJson(m['progress'] as Map<String, dynamic>);
  return ShelfBook(
    id: 0,
    fileHash: m['fileHash'] as String,
    filePath: filePath,
    coverPath: coverPath,
    title: m['title'] as String,
    author: m['author'] as String,
    authors: (m['authors'] as List<dynamic>).cast<String>(),
    description: m['description'] as String?,
    subjects: (m['subjects'] as List<dynamic>).cast<String>(),
    totalChapters: m['totalChapters'] as int,
    epubVersion: m['epubVersion'] as String,
    format: format,
    importDate: m['importDate'] as int,
    progress: progress,
    readingProgress: progress?.fraction ?? 0.0,
    lastOpenedDate: m['lastOpenedDate'] as int?,
    isFinished: m['isFinished'] as bool? ?? false,
    groupName: m['groupName'] as String?,
    isDeleted: m['isDeleted'] as bool? ?? false,
    updatedAt: m['updatedAt'] as int,
    lastSyncedDate: m['lastSyncedDate'] as int?,
    direction: m['direction'] as int? ?? 0,
  );
}

/// Deserialises a full [BookManifest] (including all embedded objects).
BookManifest mapToBookManifest(Map<String, dynamic> m) {
  return BookManifest(
    id: 0,
    fileHash: m['fileHash'] as String,
    opfRootPath: m['opfRootPath'] as String,
    epubVersion: m['epubVersion'] as String,
    format: BookFormat.values.asNameMap()[m['format']] ?? BookFormat.epub,
    lastUpdated: DateTime.parse(m['lastUpdated'] as String),
    spine: (m['spine'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_mapToSpineItem)
        .toList(),
    toc: (m['toc'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_mapToTocItem)
        .toList(),
    manifest: (m['manifest'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_mapToManifestItem)
        .toList(),
  );
}

SpineItem _mapToSpineItem(Map<String, dynamic> m) {
  return SpineItem(
    index: m['index'] as int,
    // In SpineItem, `href` is a plain String (file path relative to OPF root).
    href: m['href'] as String,
    idref: m['idref'] as String,
    linear: m['linear'] as bool? ?? true,
    properties: m['properties'] as String?,
    sourceRange: m['sourceRange'] as String?,
  );
}

Href _mapToHref(Map<String, dynamic> m) {
  return Href()
    ..path = m['path'] as String
    ..anchor = m['anchor'] as String? ?? 'top';
}

ManifestItem _mapToManifestItem(Map<String, dynamic> m) {
  return ManifestItem()
    ..id = m['id'] as String
    ..href = _mapToHref(m['href'] as Map<String, dynamic>)
    ..mediaType = m['mediaType'] as String
    ..properties = m['properties'] as String?;
}

TocItem _mapToTocItem(Map<String, dynamic> m) {
  return TocItem()
    ..id = m['id'] as int
    ..label = m['label'] as String
    ..href = _mapToHref(m['href'] as Map<String, dynamic>)
    ..depth = m['depth'] as int
    ..spineIndex = m['spineIndex'] as int? ?? -1
    ..parentId = m['parentId'] as int
    ..children = (m['children'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_mapToTocItem)
        .toList();
}
