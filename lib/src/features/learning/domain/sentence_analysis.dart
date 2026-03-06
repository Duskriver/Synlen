import 'package:isar/isar.dart';

part 'sentence_analysis.g.dart';

/// 句子分析缓存集合
@collection
class SentenceAnalysis {
  /// 自动递增主键
  Id id = Isar.autoIncrement;

  /// 句子文本 (作为索引)
  @Index(unique: true)
  late String sentence;

  /// 分析内容 (Markdown 格式)
  late String analysis;

  /// 朗读音频 URL
  String? audioUrl;

  /// 最后更新时间
  late DateTime lastUpdated;
}
