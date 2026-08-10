import 'package:isar/isar.dart';

part 'word_explanation.g.dart';

/// 单词解释缓存集合
@collection
class WordExplanation {
  /// 基于 word + context 的哈希主键，确保同一单词在同一上下文只有一条记录
  Id id = Isar.autoIncrement;

  /// 单词文本
  @Index()
  late String word;

  /// 解释内容 (Markdown 格式)
  late String explanation;

  /// 最后更新时间
  late DateTime lastUpdated;

  /// 关联的上下文 (可选，用于区分不同语境下的解释)
  String? context;

  /// 生成确定性 ID
  static int generateId(String word, String? context) {
    return _fastHash('$word|${context ?? ""}');
  }
}

/// FNV-1a 64-bit hash algorithm
int _fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}
