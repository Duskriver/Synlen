import 'package:isar/isar.dart';

part 'sentence_pronunciation.g.dart';

/// 句子发音缓存集合
@collection
class SentencePronunciation {
  /// 基于句子文本的稳定主键，确保同一句子只有一条音频缓存记录
  Id id = Isar.autoIncrement;

  /// 句子文本
  @Index(unique: true)
  late String sentence;

  /// 本地音频文件路径
  String? audioUrl;

  /// 最后更新时间
  late DateTime lastUpdated;

  /// 生成确定性 ID
  static int generateId(String sentence) {
    return _fastHash(sentence);
  }
}

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
