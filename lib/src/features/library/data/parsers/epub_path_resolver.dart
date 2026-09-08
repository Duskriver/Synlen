part of 'epub_zip_parser.dart';

Href? _resolveHref(String? href) {
  if (href == null) return null;
  final parts = href.split('#');
  return Href()
    ..path = parts[0]
    ..anchor = parts.length > 1 ? parts[1] : 'top';
}

/// Normalize path for consistent comparison
/// Removes redundant slashes and resolves relative paths
String _normalizePath(String path) {
  // Remove leading/trailing slashes
  path = path.trim();
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  // Replace multiple slashes with single slash
  path = path.replaceAll(RegExp(r'/+'), '/');
  return path;
}

/// Resolve relative path against base directory
String _resolveRelativePath(String baseDir, String relativePath) {
  if (baseDir.isEmpty) return relativePath;

  final baseUri = Uri.parse(baseDir.endsWith('/') ? baseDir : '$baseDir/');
  final resolvedUri = baseUri.resolve(relativePath);

  String result = resolvedUri.toString();
  if (result.startsWith('/')) {
    result = result.substring(1);
  }
  return Uri.decodeFull(result);
}

/// Generate relative path from base directory to target path
String _generateRelativePath(String baseDir, String path) {
  final basePath = baseDir.endsWith('/') ? baseDir : '$baseDir/';
  final targetPath = path.startsWith('/') ? path.substring(1) : path;
  if (targetPath.startsWith(basePath)) {
    String relativePath = targetPath.substring(basePath.length);
    if (relativePath.isEmpty) {
      relativePath = '.';
    }
    final normalizedRelativePath = _normalizePath(relativePath);
    return Uri.decodeFull(normalizedRelativePath);
  } else {
    return targetPath;
  }
}

bool _isWellImageFile(String path) {
  final lowerPath = path.toLowerCase();
  return lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.webp');
}
