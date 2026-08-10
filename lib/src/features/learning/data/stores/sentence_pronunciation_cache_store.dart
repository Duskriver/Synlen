import 'package:synlen/src/core/database/app_database.dart';

abstract class SentencePronunciationStore {
  Future<SentencePronunciation?> getPronunciation(String sentence);

  Future<void> saveAudioPath(String sentence, String audioPath);
}

/// 句子发音缓存（drift 实现）。
/// 主键使用 sentence 的确定性哈希，保证同一句子只有一条记录。
class SentencePronunciationCacheStore implements SentencePronunciationStore {
  final AppDatabase _db;

  SentencePronunciationCacheStore(this._db);

  @override
  Future<SentencePronunciation?> getPronunciation(String sentence) {
    return (_db.select(_db.sentencePronunciations)
          ..where((t) => t.id.equals(sentencePronunciationId(sentence))))
        .getSingleOrNull();
  }

  @override
  Future<void> saveAudioPath(String sentence, String audioPath) async {
    await _db.into(_db.sentencePronunciations).insertOnConflictUpdate(
          SentencePronunciation(
            id: sentencePronunciationId(sentence),
            sentence: sentence,
            audioUrl: audioPath,
            lastUpdated: DateTime.now(),
          ),
        );
  }
}
