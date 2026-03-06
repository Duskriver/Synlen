import 'package:isar/isar.dart';

part 'word_explanation.g.dart';

/// 单词解释缓存集合
@collection
class WordExplanation {
  /// 自动递增主键
  Id id = Isar.autoIncrement;

  /// 单词文本
  @Index(unique: true)
  late String word;

  /// 解释内容 (Markdown 格式)
  late String explanation;

  /// 最后更新时间
  late DateTime lastUpdated;

  /// 关联的上下文 (可选，用于区分不同语境下的解释)
  String? context;

  /// 发音音频 URL
  String? audioUrl;
}
