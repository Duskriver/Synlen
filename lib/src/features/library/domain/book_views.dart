import 'book_format.dart';

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
