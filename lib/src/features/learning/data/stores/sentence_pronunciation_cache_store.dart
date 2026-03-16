import 'package:isar/isar.dart';
import 'package:synlen/src/features/learning/domain/sentence_pronunciation.dart';

abstract class SentencePronunciationStore {
  Future<SentencePronunciation?> getPronunciation(String sentence);

  Future<void> saveAudioPath(String sentence, String audioPath);
}

class SentencePronunciationCacheStore implements SentencePronunciationStore {
  final Isar _isar;

  SentencePronunciationCacheStore(this._isar);

  @override
  Future<SentencePronunciation?> getPronunciation(String sentence) {
    return _isar.sentencePronunciations.get(
      SentencePronunciation.generateId(sentence),
    );
  }

  @override
  Future<void> saveAudioPath(String sentence, String audioPath) async {
    final cached = await getPronunciation(sentence);
    final entry =
        cached ??
        (SentencePronunciation()
          ..id = SentencePronunciation.generateId(sentence)
          ..sentence = sentence);

    entry
      ..audioUrl = audioPath
      ..lastUpdated = DateTime.now();

    await _isar.writeTxn(() => _isar.sentencePronunciations.put(entry));
  }
}
