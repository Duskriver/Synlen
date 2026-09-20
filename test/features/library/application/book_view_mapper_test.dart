import '../../../helpers/book_progress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_view_mapper.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

ShelfBook buildBook() => ShelfBook(
  id: 7,
  fileHash: 'hash7',
  title: '测试书',
  author: '作者',
  authors: const ['作者', '合著者'],
  subjects: const ['科幻'],
  totalChapters: 12,
  epubVersion: '3.0',
  format: BookFormat.txt,
  importDate: 0,
  direction: 1,

  progress: testBookProgress(chapter: 3),
  readingProgress: 0.5,
  isFinished: false,
  isDeleted: false,
  updatedAt: 0,
);

void main() {
  test('shelfBookView 映射网格卡片需要的字段', () {
    final view = shelfBookView(buildBook());

    expect(view.id, 7);
    expect(view.fileHash, 'hash7');
    expect(view.title, '测试书');
    expect(view.author, '作者');
    expect(view.coverPath, isNull);
    expect(view.readingProgress, 0.5);
    expect(view.isFinished, isFalse);
    expect(view.isDeleted, isFalse);
  });

  test('detailBookView 映射详情视图需要的字段', () {
    final view = detailBookView(buildBook());

    expect(view.id, 7);
    expect(view.fileHash, 'hash7');
    expect(view.title, '测试书');
    expect(view.authors, ['作者', '合著者']);
    expect(view.totalChapters, 12);
    expect(view.epubVersion, '3.0');
    expect(view.format, BookFormat.txt);
    expect(view.direction, 1);
    expect(view.readingProgress, 0.5);
    expect(view.coverPath, isNull);
  });

  test('editableBookView 从详情视图只取主键与封面路径', () {
    final view = editableBookView(detailBookView(buildBook()));

    expect(view.id, 7);
    expect(view.coverPath, isNull);
  });

  test('readerBookView 映射阅读会话需要的字段', () {
    final view = readerBookView(buildBook());

    expect(view.id, 7);
    expect(view.title, '测试书');
    expect(view.author, '作者');
    expect(view.coverPath, isNull);
    expect(view.filePath, isNull);
    expect(view.totalChapters, 12);
    expect(view.direction, 1);
    expect(view.progress, testBookProgress(chapter: 3));
    expect(view.format, BookFormat.txt);
  });

  test('readerManifestView 只取 spine 与目录', () {
    final spine = [SpineItem(index: 0, href: 'ch1.xhtml')];
    final toc = [
      TocItem(
        label: '第一章',
        href: Href(path: 'ch1.xhtml'),
      ),
    ];
    final view = readerManifestView(
      BookManifest(
        id: 3,
        fileHash: 'hash7',
        opfRootPath: 'OEBPS/',
        spine: spine,
        toc: toc,
        manifest: const [],
        epubVersion: '3.0',
        format: BookFormat.epub,
        lastUpdated: DateTime(2026, 1, 1),
      ),
    );

    expect(view.spine, same(spine));
    expect(view.toc, same(toc));
  });
}
