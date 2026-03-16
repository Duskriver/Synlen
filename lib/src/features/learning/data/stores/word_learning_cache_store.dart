import 'package:isar/isar.dart';
import 'package:synlen/src/features/learning/domain/word_explanation.dart';
import 'package:synlen/src/features/learning/domain/word_pronunciation.dart';

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

class WordLearningCacheStore implements WordCacheStore {
  final Isar _isar;

  WordLearningCacheStore(this._isar);

  @override
  Future<WordExplanation?> getExplanation(String word, String context) {
    return _isar.wordExplanations.get(
      WordExplanation.generateId(word, context),
    );
  }

  @override
  Future<WordPronunciation?> getPronunciation(String word) {
    return _isar.wordPronunciations.get(WordPronunciation.generateId(word));
  }

  @override
  Future<void> saveExplanation({
    required String word,
    required String context,
    required String explanation,
  }) async {
    final cached = await getExplanation(word, context);
    final entry =
        cached ??
        (WordExplanation()
          ..id = WordExplanation.generateId(word, context)
          ..word = word
          ..context = context);

    entry
      ..word = word
      ..context = context
      ..explanation = explanation
      ..lastUpdated = DateTime.now();

    await _isar.writeTxn(() => _isar.wordExplanations.put(entry));
  }

  @override
  Future<void> savePronunciationPath(String word, String audioPath) async {
    final cached = await getPronunciation(word);
    final entry =
        cached ??
        (WordPronunciation()
          ..id = WordPronunciation.generateId(word)
          ..word = word);

    entry
      ..audioUrl = audioPath
      ..lastUpdated = DateTime.now();

    await _isar.writeTxn(() => _isar.wordPronunciations.put(entry));
  }
}
