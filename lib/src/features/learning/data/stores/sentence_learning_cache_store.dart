import 'package:isar/isar.dart';
import 'package:synlen/src/features/learning/domain/sentence_analysis.dart';

abstract class SentenceAnalysisStore {
  Future<SentenceAnalysis?> getSentence(String sentence);

  Future<void> saveAnalysis({
    required String sentence,
    required String analysis,
  });
}

class SentenceLearningCacheStore implements SentenceAnalysisStore {
  final Isar _isar;

  SentenceLearningCacheStore(this._isar);

  @override
  Future<SentenceAnalysis?> getSentence(String sentence) {
    return _isar.sentenceAnalysis.where().sentenceEqualTo(sentence).findFirst();
  }

  @override
  Future<void> saveAnalysis({
    required String sentence,
    required String analysis,
  }) async {
    final cached = await getSentence(sentence);
    final entry = cached ?? (SentenceAnalysis()..sentence = sentence);

    entry
      ..sentence = sentence
      ..analysis = analysis
      ..lastUpdated = DateTime.now();

    await _isar.writeTxn(() => _isar.sentenceAnalysis.put(entry));
  }
}
