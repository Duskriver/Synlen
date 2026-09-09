import '../../library/domain/book_views.dart';
import 'package:synlen/src/core/database/app_database.dart';

/// drift 行 → 视图的映射集中在这里：presentation 与 reader 只吃视图类型。
ShelfBookView shelfBookView(ShelfBook book) => (
  id: book.id,
  fileHash: book.fileHash,
  title: book.title,
  author: book.author,
  coverPath: book.coverPath,
  readingProgress: book.readingProgress,
  isFinished: book.isFinished,
  isDeleted: book.isDeleted,
);

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

/// 编辑表单只取主键与封面路径；来源是详情视图，不再回头读 drift 行。
EditableBookView editableBookView(DetailBookView book) =>
    (id: book.id, coverPath: book.coverPath);

/// 阅读会话只取渲染与进度落库需要的字段。
ReaderBookView readerBookView(ShelfBook book) => (
  id: book.id,
  title: book.title,
  author: book.author,
  coverPath: book.coverPath,
  filePath: book.filePath,
  totalChapters: book.totalChapters,
  direction: book.direction,
  currentChapterIndex: book.currentChapterIndex,
  chapterScrollPosition: book.chapterScrollPosition,
);

/// 阅读会话只取 spine 与目录。
ReaderManifestView readerManifestView(BookManifest manifest) =>
    (spine: manifest.spine, toc: manifest.toc);
