import 'package:drift/drift.dart';
import 'package:synlen/src/core/database/app_database.dart';

abstract class SentenceAnalysisStore {
  Future<SentenceAnalysis?> getSentence(String sentence);

  Future<void> saveAnalysis({
    required String sentence,
    required String analysis,
  });
}

/// 句子分析缓存（drift 实现）。
/// 存储键带 prompt 版本前缀：输出契约变更时旧缓存自然失效。
class SentenceLearningCacheStore implements SentenceAnalysisStore {
  final AppDatabase _db;

  SentenceLearningCacheStore(this._db);

  String _cacheKey(String sentence) => 'v$kLearningTextPromptVersion|$sentence';

  @override
  Future<SentenceAnalysis?> getSentence(String sentence) {
    return (_db.select(
      _db.sentenceAnalyses,
    )..where((t) => t.sentence.equals(_cacheKey(sentence)))).getSingleOrNull();
  }

  @override
  Future<void> saveAnalysis({
    required String sentence,
    required String analysis,
  }) async {
    final cached = await getSentence(sentence);
    if (cached == null) {
      await _db
          .into(_db.sentenceAnalyses)
          .insert(
            SentenceAnalysesCompanion.insert(
              sentence: _cacheKey(sentence),
              analysis: analysis,
              lastUpdated: DateTime.now(),
            ),
          );
    } else {
      await (_db.update(
        _db.sentenceAnalyses,
      )..where((t) => t.id.equals(cached.id))).write(
        SentenceAnalysesCompanion(
          analysis: Value(analysis),
          lastUpdated: Value(DateTime.now()),
        ),
      );
    }
  }
}
