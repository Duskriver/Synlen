import 'package:synlen/src/features/library/domain/book_progress.dart';

/// 用完整定位构造书库测试的位置，保留文本上下文以验证备份不会裁剪字段。
BookProgress testBookProgress({
  int chapter = 0,
  double fraction = 0.5,
  double within = 0.25,
}) => BookProgress.fromLocator({
  'href': 'chapter$chapter.xhtml',
  'type': 'application/xhtml+xml',
  'title': '第 $chapter 章',
  'locations': {'progression': within, 'totalProgression': fraction},
  'text': {'highlight': '保存的文本', 'before': '前文', 'after': '后文'},
  'extensions': {'retained': true},
});
