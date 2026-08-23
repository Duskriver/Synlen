import 'package:synlen/src/core/database/app_database.dart';

abstract class WordCacheStore {
  Future<WordExplanation?> getExplanation(String word, String context);

  Future<WordPronunciation?> getPronunciation(String word);

  Future<void> saveExplanation({
    required String word,
    required String context,
    required String explanation,
  });

  Future<void> savePronunciationPath(String word, String audioPath);
}

/// 单词学习缓存（drift 实现）。
/// 主键使用确定性哈希（word/word+context），保证同一词条只有一条记录。
class WordLearningCacheStore implements WordCacheStore {
  final AppDatabase _db;

  WordLearningCacheStore(this._db);

  @override
  Future<WordExplanation?> getExplanation(String word, String context) {
    return (_db.select(_db.wordExplanations)
          ..where((t) => t.id.equals(wordExplanationId(word, context))))
        .getSingleOrNull();
  }

  @override
  Future<WordPronunciation?> getPronunciation(String word) {
    return (_db.select(
      _db.wordPronunciations,
    )..where((t) => t.id.equals(wordPronunciationId(word)))).getSingleOrNull();
  }

  @override
  Future<void> saveExplanation({
    required String word,
    required String context,
    required String explanation,
  }) async {
    await _db
        .into(_db.wordExplanations)
        .insertOnConflictUpdate(
          WordExplanation(
            id: wordExplanationId(word, context),
            word: word,
            context: context,
            explanation: explanation,
            lastUpdated: DateTime.now(),
          ),
        );
  }

  @override
  Future<void> savePronunciationPath(String word, String audioPath) async {
    await _db
        .into(_db.wordPronunciations)
        .insertOnConflictUpdate(
          WordPronunciation(
            id: wordPronunciationId(word),
            word: word,
            audioUrl: audioPath,
            lastUpdated: DateTime.now(),
          ),
        );
  }
}
