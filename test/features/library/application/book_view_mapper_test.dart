import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_view_mapper.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

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
  currentChapterIndex: 3,
  readingProgress: 0.5,
  isFinished: false,
  isDeleted: false,
  updatedAt: 0,
);

void main() {
  test('gridBookView 映射网格卡片需要的字段', () {
    final view = gridBookView(buildBook());

    expect(view.id, 7);
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

  test('editableBookView 只取主键与封面路径', () {
    final view = editableBookView(buildBook());

    expect(view.id, 7);
    expect(view.coverPath, isNull);
  });
}
