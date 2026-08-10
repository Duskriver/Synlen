import 'package:isar/isar.dart';

part 'word_pronunciation.g.dart';

/// 单词发音缓存集合
@collection
class WordPronunciation {
  /// 基于单词文本的稳定主键，确保同一单词只有一条音频缓存记录
  Id id = Isar.autoIncrement;

  /// 单词文本
  @Index(unique: true)
  late String word;

  /// 本地音频文件路径
  String? audioUrl;

  /// 最后更新时间
  late DateTime lastUpdated;

  /// 生成确定性 ID
  static int generateId(String word) {
    return _fastHash(word);
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
