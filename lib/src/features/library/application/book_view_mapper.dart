import '../../library/domain/book_views.dart';
import 'package:synlen/src/core/database/app_database.dart';

/// drift 行 → 展示视图的映射集中在这里：presentation 只吃视图类型。
DetailBookView detailBookView(ShelfBook book) => (
  id: book.id,
  fileHash: book.fileHash,
  title: book.title,
  authors: book.authors,
  description: book.description,
  coverPath: book.coverPath,
  totalChapters: book.totalChapters,
  epubVersion: book.epubVersion,
  format: book.format,
  direction: book.direction,
  readingProgress: book.readingProgress,
);

EditableBookView editableBookView(ShelfBook book) =>
    (id: book.id, coverPath: book.coverPath);
