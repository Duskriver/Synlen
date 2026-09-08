import 'book_format.dart';

/// 分组选项：标签页与对话框只需要 id 与名称，不持有持久化行类型。
typedef GroupOption = ({int id, String name});

/// 书架网格卡片需要的书目字段；不持有持久化行类型。
typedef GridBookView = ({
  int id,
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
