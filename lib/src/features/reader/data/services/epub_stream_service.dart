import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

import 'epub_backend.dart';

/// EPUB 内容读取：切换书籍时关闭上一本的 Rust 缓存条目。
class EpubStreamService {
  EpubStreamService({EpubBackend backend = const RustEpubBackend()})
    : _backend = backend;

  final EpubBackend _backend;

  String? _currentBookPath;
  String? _pendingBookPath;
  Future<void>? _openBookFuture;

  Future<void> openBook(String epubPath) {
    if (_currentBookPath == epubPath) {
      return Future.value();
    }

    if (_pendingBookPath == epubPath && _openBookFuture != null) {
      return _openBookFuture!;
    }

    _pendingBookPath = epubPath;
    _openBookFuture = _doOpenBook(epubPath);
    return _openBookFuture!;
  }

  Future<void> _doOpenBook(String epubPath) async {
    final previous = _currentBookPath;
    try {
      // 切书时关闭上一本的缓存条目：Rust 侧按书路径缓存，不关会随阅读累积。
      if (previous != null && previous != epubPath) {
        await _backend.close(previous);
      }
      await _backend.load(epubPath);
      _currentBookPath = epubPath;
    } catch (e) {
      _currentBookPath = null;
      rethrow;
    } finally {
      if (_pendingBookPath == epubPath) {
        _pendingBookPath = null;
        _openBookFuture = null;
      }
    }
  }

  Future<Either<String, Uint8List>> readFileFromEpub({
    required String targetFilePath,
    String? epubPath,
  }) async {
    if (epubPath != null && epubPath != _currentBookPath) {
      try {
        await openBook(epubPath);
      } catch (e) {
        return left('Failed to open book: $e');
      }
    }

    if (_currentBookPath == null) {
      return left('No book is currently loaded');
    }

    try {
      final data = await _backend.readFile(
        epubPath: _currentBookPath!,
        filePath: targetFilePath,
      );
      if (data == null) {
        return left('File not found: $targetFilePath');
      }
      return right(data);
    } catch (e) {
      return left('Read error: $e');
    }
  }

  void dispose() {
    if (_currentBookPath != null) {
      _backend.close(_currentBookPath!).ignore();
      _currentBookPath = null;
      _pendingBookPath = null;
      _openBookFuture = null;
    }
  }

  String getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    return _mimeTypeMap[ext] ?? 'application/octet-stream';
  }

  static const _mimeTypeMap = {
    'html': 'text/html',
    'htm': 'text/html',
    'xhtml': 'application/xhtml+xml',
    'xml': 'application/xml',
    'css': 'text/css',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'webp': 'image/webp',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'js': 'application/javascript',
  };
}
