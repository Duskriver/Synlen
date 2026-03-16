import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/domain/sentence_analysis.dart';
import 'package:synlen/src/features/learning/domain/sentence_pronunciation.dart';
import 'package:synlen/src/features/learning/domain/word_explanation.dart';
import 'package:synlen/src/features/learning/domain/word_pronunciation.dart';

class InMemoryAudioFileStore implements AudioFileStore {
  final Map<String, String?> wordAudioPaths;
  final Map<String, String?> sentenceAudioPaths;

  InMemoryAudioFileStore({
    Map<String, String?>? wordAudioPaths,
    Map<String, String?>? sentenceAudioPaths,
  }) : wordAudioPaths = wordAudioPaths ?? {},
       sentenceAudioPaths = sentenceAudioPaths ?? {};

  @override
  Future<String?> resolveWordAudioPath(
    String word, {
    String? preferredPath,
  }) async {
    return wordAudioPaths[word] ?? preferredPath;
  }

  @override
  Future<String> saveWordAudioFile(String word, List<int> bytes) async {
    return wordAudioPaths[word] ??= '/tmp/$word.wav';
  }

  @override
  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
  }) async {
    return sentenceAudioPaths[sentence] ?? preferredPath;
  }

  @override
  Future<String> saveSentenceAudioFile(String sentence, List<int> bytes) async {
    return sentenceAudioPaths[sentence] ??= '/tmp/sentence.wav';
  }
}

class InMemoryWordCacheStore implements WordCacheStore {
  final Map<String, WordExplanation> explanations = {};
  final Map<String, WordPronunciation> pronunciations = {};

  @override
  Future<WordExplanation?> getExplanation(String word, String context) async {
    return explanations['$word|$context'];
  }

  @override
  Future<WordPronunciation?> getPronunciation(String word) async {
    return pronunciations[word];
  }

  @override
  Future<void> saveExplanation({
    required String word,
    required String context,
    required String explanation,
  }) async {
    explanations['$word|$context'] = WordExplanation()
      ..id = WordExplanation.generateId(word, context)
      ..word = word
      ..context = context
      ..explanation = explanation
      ..lastUpdated = DateTime(2025);
  }

  @override
  Future<void> savePronunciationPath(String word, String audioPath) async {
    pronunciations[word] = WordPronunciation()
      ..id = WordPronunciation.generateId(word)
      ..word = word
      ..audioUrl = audioPath
      ..lastUpdated = DateTime(2025);
  }
}

class InMemorySentenceAnalysisStore implements SentenceAnalysisStore {
  final Map<String, SentenceAnalysis> analyses = {};

  @override
  Future<SentenceAnalysis?> getSentence(String sentence) async {
    return analyses[sentence];
  }

  @override
  Future<void> saveAnalysis({
    required String sentence,
    required String analysis,
  }) async {
    analyses[sentence] = SentenceAnalysis()
      ..sentence = sentence
      ..analysis = analysis
      ..lastUpdated = DateTime(2025);
  }
}

class InMemorySentencePronunciationStore implements SentencePronunciationStore {
  final Map<String, SentencePronunciation> pronunciations = {};

  @override
  Future<SentencePronunciation?> getPronunciation(String sentence) async {
    return pronunciations[sentence];
  }

  @override
  Future<void> saveAudioPath(String sentence, String audioPath) async {
    pronunciations[sentence] = SentencePronunciation()
      ..id = SentencePronunciation.generateId(sentence)
      ..sentence = sentence
      ..audioUrl = audioPath
      ..lastUpdated = DateTime(2025);
  }
}

void main() {
  group('WordRepository cache independence', () {
    late InMemoryWordCacheStore cacheStore;

    setUp(() {
      cacheStore = InMemoryWordCacheStore();
    });

    test(
      'returns only text cache when explanation exists and audio is missing',
      () async {
        const word = 'clarity';
        const context = 'Clarity matters.';

        await cacheStore.saveExplanation(
          word: word,
          context: context,
          explanation: 'cached explanation',
        );

        final repository = WordRepository(
          FreeDictionaryService(),
          DeepSeekService(),
          AliyunTTSService(),
          cacheStore,
          InMemoryAudioFileStore(),
        );

        final result = await repository.getWordInfo(word, context);

        expect(result.explanation, 'cached explanation');
        expect(result.audioUrl, isNull);
        expect(result.hasCachedExplanation, isTrue);
        expect(result.hasCachedAudio, isFalse);
      },
    );

    test(
      'returns only audio cache when pronunciation exists and explanation is missing',
      () async {
        const word = 'clarity';
        const context = 'Clarity matters.';

        await cacheStore.savePronunciationPath(word, '/tmp/clarity.wav');

        final repository = WordRepository(
          FreeDictionaryService(),
          DeepSeekService(),
          AliyunTTSService(),
          cacheStore,
          InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/clarity.wav'}),
        );

        final result = await repository.getWordInfo(word, context);

        expect(result.explanation, isNull);
        expect(result.audioUrl, '/tmp/clarity.wav');
        expect(result.hasCachedExplanation, isFalse);
        expect(result.hasCachedAudio, isTrue);
      },
    );
  });

  group('SentenceRepository cache independence', () {
    late InMemorySentenceAnalysisStore analysisStore;
    late InMemorySentencePronunciationStore pronunciationStore;

    setUp(() {
      analysisStore = InMemorySentenceAnalysisStore();
      pronunciationStore = InMemorySentencePronunciationStore();
    });

    test(
      'returns only text cache when analysis exists and audio is missing',
      () async {
        const sentence = 'Clarity matters.';

        await analysisStore.saveAnalysis(
          sentence: sentence,
          analysis: 'cached analysis',
        );

        final repository = SentenceRepository(
          DeepSeekService(),
          AliyunTTSService(),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(),
        );

        final result = await repository.getSentenceInfo(sentence);

        expect(result.analysis, 'cached analysis');
        expect(result.audioUrl, isNull);
        expect(result.hasCachedAnalysis, isTrue);
        expect(result.hasCachedAudio, isFalse);
      },
    );

    test(
      'returns only audio cache when pronunciation exists and analysis is missing',
      () async {
        const sentence = 'Clarity matters.';

        await pronunciationStore.saveAudioPath(sentence, '/tmp/sentence.wav');

        final repository = SentenceRepository(
          DeepSeekService(),
          AliyunTTSService(),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(
            sentenceAudioPaths: {sentence: '/tmp/sentence.wav'},
          ),
        );

        final result = await repository.getSentenceInfo(sentence);

        expect(result.analysis, isNull);
        expect(result.audioUrl, '/tmp/sentence.wav');
        expect(result.hasCachedAnalysis, isFalse);
        expect(result.hasCachedAudio, isTrue);
      },
    );
  });
}
