import 'book_format.dart';
import 'book_manifest.dart';

/// 分组选项：标签页与对话框只需要 id 与名称，不持有持久化行类型。
typedef GroupOption = ({int id, String name});

/// 书架列表项需要的书目字段；不持有持久化行类型。
///
/// 带 `fileHash` 是因为它就是详情路由的主键：网格点击只传哈希，详情页自己取数据。
typedef ShelfBookView = ({
  int id,
  String fileHash,
  String title,
  String author,
  String? coverPath,
  double readingProgress,
  bool isFinished,
  bool isDeleted,
});

/// 详情只读视图需要的书目字段；不持有持久化行类型。
typedef DetailBookView = ({
  int id,
  String fileHash,
  String title,
  List<String> authors,
  String? description,
  String? coverPath,
  int totalChapters,
  String epubVersion,
  BookFormat format,
  int direction,
  double readingProgress,
});

/// 详情编辑表单需要的字段：主键（封面 hero tag）与封面路径。
typedef EditableBookView = ({int id, String? coverPath});

/// 阅读会话需要的书目字段；不持有持久化行类型。
///
/// `id` 是进度落库的行主键；`filePath` 供 EPUB 后端按路径取条目；
/// `author` / `coverPath` / `totalChapters` 供目录抽屉的书目头部展示。
typedef ReaderBookView = ({
  int id,
  String title,
  String author,
  String? coverPath,
  String? filePath,
  int totalChapters,
  int direction,
  int currentChapterIndex,
  double? chapterScrollPosition,
});

/// 阅读会话需要的清单字段：spine 与目录；不持有持久化行类型。
typedef ReaderManifestView = ({List<SpineItem> spine, List<TocItem> toc});
