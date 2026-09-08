import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/services/backup_json_mapper.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

void main() {
  group('mapToShelfGroup', () {
    test('映射字段并忽略备份里的主键', () {
      final group = mapToShelfGroup({
        'id': 99,
        'name': '科幻',
        'creationDate': 100,
        'updatedAt': 200,
      });

      expect(group.id, 0);
      expect(group.name, '科幻');
      expect(group.creationDate, 100);
      expect(group.updatedAt, 200);
      expect(group.isDeleted, isFalse);
    });
  });

  group('mapToShelfBook', () {
    Map<String, dynamic> bookJson() => {
      'fileHash': 'hash1',
      'title': '测试书',
      'author': '作者',
      'authors': ['作者', '合著者'],
      'subjects': ['科幻'],
      'totalChapters': 12,
      'epubVersion': '3.0',
      'importDate': 1,
      'updatedAt': 2,
      'currentChapterIndex': 3,
      'readingProgress': 0.5,
      'chapterScrollPosition': 0.25,
      'lastOpenedDate': 4,
      'isFinished': true,
      'groupName': '科幻',
      'isDeleted': true,
      'lastSyncedDate': 5,
      'direction': 1,
    };

    test('映射字段，路径与格式由调用方注入', () {
      final book = mapToShelfBook(
        bookJson(),
        filePath: 'books/hash1.epub',
        coverPath: 'covers/hash1.png',
        format: BookFormat.epub,
      );

      expect(book.id, 0);
      expect(book.fileHash, 'hash1');
      expect(book.filePath, 'books/hash1.epub');
      expect(book.coverPath, 'covers/hash1.png');
      expect(book.format, BookFormat.epub);
      expect(book.authors, ['作者', '合著者']);
      expect(book.subjects, ['科幻']);
      expect(book.currentChapterIndex, 3);
      expect(book.readingProgress, 0.5);
      expect(book.chapterScrollPosition, 0.25);
      expect(book.isFinished, isTrue);
      expect(book.isDeleted, isTrue);
      expect(book.direction, 1);
    });

    test('缺省字段回落到默认值', () {
      final book = mapToShelfBook(
        {
          'fileHash': 'hash1',
          'title': '测试书',
          'author': '作者',
          'authors': <String>[],
          'subjects': <String>[],
          'totalChapters': 0,
          'epubVersion': '',
          'importDate': 0,
          'updatedAt': 0,
        },
        filePath: null,
        coverPath: null,
        format: BookFormat.txt,
      );

      expect(book.currentChapterIndex, 0);
      expect(book.readingProgress, 0.0);
      expect(book.chapterScrollPosition, isNull);
      expect(book.isFinished, isFalse);
      expect(book.isDeleted, isFalse);
      expect(book.direction, 0);
      expect(book.filePath, isNull);
    });
  });

  group('mapToBookManifest', () {
    test('递归映射 spine、toc 与 manifest', () {
      final manifest = mapToBookManifest({
        'fileHash': 'hash1',
        'opfRootPath': 'OEBPS/',
        'epubVersion': '3.0',
        'format': 'txt',
        'lastUpdated': '2026-01-02T03:04:05.000',
        'spine': [
          {
            'index': 0,
            'href': 'txt/chapter_0.xhtml',
            'idref': 'txt-chapter-0',
            'linear': false,
            'properties': 'page-spread-left',
            'sourceRange': '0-10',
          },
        ],
        'toc': [
          {
            'id': 1,
            'label': '第一章',
            'href': {'path': 'txt/chapter_0.xhtml', 'anchor': 'top'},
            'depth': 0,
            'spineIndex': 0,
            'parentId': -1,
            'children': [
              {
                'id': 2,
                'label': '第一节',
                'href': {'path': 'txt/chapter_0.xhtml', 'anchor': 'sec1'},
                'depth': 1,
                'spineIndex': 0,
                'parentId': 1,
                'children': <Map<String, dynamic>>[],
              },
            ],
          },
        ],
        'manifest': [
          {
            'id': 'ch0',
            'href': {'path': 'txt/chapter_0.xhtml', 'anchor': 'top'},
            'mediaType': 'application/xhtml+xml',
            'properties': null,
          },
        ],
      });

      expect(manifest.id, 0);
      expect(manifest.format, BookFormat.txt);
      expect(manifest.lastUpdated, DateTime(2026, 1, 2, 3, 4, 5));
      expect(manifest.spine.single.linear, isFalse);
      expect(manifest.spine.single.sourceRange, '0-10');
      expect(manifest.toc.single.children.single.label, '第一节');
      expect(manifest.toc.single.children.single.href.anchor, 'sec1');
      expect(manifest.manifest.single.mediaType, 'application/xhtml+xml');
    });

    test('未知格式回退 EPUB', () {
      final manifest = mapToBookManifest({
        'fileHash': 'hash1',
        'opfRootPath': '',
        'epubVersion': '2.0',
        'format': 'mobi',
        'lastUpdated': '2026-01-01T00:00:00.000',
        'spine': <Map<String, dynamic>>[],
        'toc': <Map<String, dynamic>>[],
        'manifest': <Map<String, dynamic>>[],
      });

      expect(manifest.format, BookFormat.epub);
    });
  });
}
