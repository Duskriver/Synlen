import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/storage/app_storage.dart';
import '../../library/application/book_queries.dart';
import '../../library/domain/book_format.dart';
import '../../library/domain/book_views.dart';
import '../data/readium_epub_publication_cache.dart';
import '../data/readium_txt_publication_cache.dart';

/// 原生阅读器的本地文件及书目上下文；路径不是 file URI。
typedef PreparedReadiumPublication = ({
  String path,
  ReaderBookView book,
  ReaderManifestView manifest,
});

/// 为阅读会话准备文件；错误由会话 controller 转换为可展示状态。
class ReadiumPublicationSource {
  const ReadiumPublicationSource({
    required BookQueries queries,
    required ReadiumTxtPublicationCache txtCache,
    required ReadiumEpubPublicationCache epubCache,
    required String documentsDirectory,
  }) : _queries = queries,
       _txtCache = txtCache,
       _epubCache = epubCache,
       _documentsDirectory = documentsDirectory;

  final BookQueries _queries;
  final ReadiumTxtPublicationCache _txtCache;
  final ReadiumEpubPublicationCache _epubCache;
  final String _documentsDirectory;

  Future<PreparedReadiumPublication> open(String fileHash) async {
    final book = await _queries.findBook(fileHash);
    final manifest = await _queries.findManifest(fileHash);
    final relativePath = book?.filePath;
    if (book == null || manifest == null || relativePath == null) {
      throw StateError('阅读书籍或清单不存在');
    }
    final sourcePath = p.normalize(p.join(_documentsDirectory, relativePath));
    if (!p.isWithin(_documentsDirectory, sourcePath) ||
        !await File(sourcePath).exists()) {
      throw StateError('阅读源文件不存在或路径无效');
    }
    final path = switch (book.format) {
      BookFormat.epub => await _epubCache.prepare(sourcePath),
      BookFormat.txt => await _txtCache.prepare(
        sourcePath: sourcePath,
        title: book.title,
        author: book.author,
        manifest: manifest,
      ),
    };
    return (path: path, book: book, manifest: manifest);
  }
}

final readiumPublicationSourceProvider = Provider<ReadiumPublicationSource>((
  ref,
) {
  return ReadiumPublicationSource(
    queries: ref.watch(bookQueriesProvider),
    txtCache: ReadiumTxtPublicationCache(
      cacheDirectory: p.join(
        AppStorage.tempPath,
        'readium-publications',
        'txt',
      ),
    ),
    epubCache: ReadiumEpubPublicationCache(
      cacheDirectory: p.join(
        AppStorage.tempPath,
        'readium-publications',
        'epub',
      ),
    ),
    documentsDirectory: AppStorage.documentsPath,
  );
});
