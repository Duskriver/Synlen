import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_progress.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/application/readium_publication_source.dart';
import 'package:synlen/src/features/reader/data/readium_txt_publication_cache.dart';
import 'package:synlen/src/features/reader/data/readium_epub_publication_cache.dart';
import '../../../helpers/epub_fixture.dart';

class _Queries implements BookQueries {
  ReaderBookView? book;
  ReaderManifestView? manifest = (spine: [], toc: []);

  @override
  Future<ReaderBookView?> findBook(String fileHash) async => book;
  @override
  Future<ReaderManifestView?> findManifest(String fileHash) async => manifest;
  @override
  Future<void> saveProgress({
    required int bookId,
    required BookProgress progress,
  }) async {}
}

void main() {
  late Directory directory;
  late _Queries queries;
  late ReadiumPublicationSource source;

  ReaderBookView book(BookFormat format, String path) => (
    id: 3,
    title: '书名',
    author: '作者',
    coverPath: null,
    filePath: path,
    totalChapters: 1,
    direction: 0,
    format: format,
    progress: null,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('readium-source-');
    queries = _Queries();
    source = ReadiumPublicationSource(
      queries: queries,
      epubCache: ReadiumEpubPublicationCache(
        cacheDirectory: p.join(directory.path, 'epub-cache'),
      ),
      txtCache: ReadiumTxtPublicationCache(
        cacheDirectory: p.join(directory.path, 'cache'),
      ),
      documentsDirectory: directory.path,
    );
  });
  tearDown(() async => directory.delete(recursive: true));

  test('EPUB 返回原文件绝对路径，未保存进度保持 null', () async {
    final original = await File(
      p.join(directory.path, 'original.epub'),
    ).writeAsBytes(testEpubBytes());
    queries.book = book(BookFormat.epub, 'original.epub');
    final result = await source.open('hash');
    expect(result.path, original.path);
    expect(result.book.progress, isNull);
    expect(result.manifest, queries.manifest);
    expect(Directory(p.join(directory.path, 'cache')).existsSync(), isFalse);
  });

  test('TXT 装配真实正文缓存，不把源 TXT 路径传给原生阅读器', () async {
    await File(p.join(directory.path, 'source.txt')).writeAsString('正文');
    queries.book = book(BookFormat.txt, 'source.txt');
    queries.manifest = (
      spine: [SpineItem(href: 'txt/chapter_0.xhtml', sourceRange: '0-6')],
      toc: [],
    );
    final result = await source.open('hash');
    expect(result.path, endsWith('.epub'));
    expect(File(result.path).existsSync(), isTrue);
    expect(
      await File(p.join(directory.path, 'source.txt')).readAsString(),
      '正文',
    );
  });

  test('缺失书目、清单、正文或越界路径交给 controller 处理', () async {
    await expectLater(source.open('missing'), throwsStateError);
    queries.book = book(BookFormat.epub, '../outside.epub');
    await expectLater(source.open('hash'), throwsStateError);
    queries.book = book(BookFormat.epub, 'missing.epub');
    await expectLater(source.open('hash'), throwsStateError);
    queries.manifest = null;
    await expectLater(source.open('hash'), throwsStateError);
  });
}
