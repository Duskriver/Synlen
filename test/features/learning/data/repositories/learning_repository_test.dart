import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:synlen/src/features/learning/application/learning_streaming_audio_session.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/core/database/app_database.dart';

import '../../word_definition_fixture.dart';

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
    String? voice,
  }) async {
    return wordAudioPaths[word] ?? preferredPath;
  }

  @override
  Future<String> saveWordAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format, {
    String? voice,
    bool cacheByVoice = false,
  }) async {
    return wordAudioPaths[word] ??= '/tmp/$word.pcm';
  }

  @override
  Future<String?> resolveSentenceAudioPath(
    String sentence, {
    String? preferredPath,
    required String voice,
  }) async {
    return sentenceAudioPaths[sentence] ?? preferredPath;
  }

  @override
  Future<String> saveSentenceAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format, {
    required String voice,
  }) async {
    return sentenceAudioPaths[sentence] ??= '/tmp/sentence.pcm';
  }

  @override
  Future<int> evictAudioCache({int? maxBytes}) async => 0;
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
    explanations['$word|$context'] = WordExplanation(
      id: wordExplanationId(word, context),
      word: word,
      context: context,
      explanation: explanation,
      lastUpdated: DateTime(2025),
    );
  }

  @override
  Future<void> savePronunciationPath(String word, String audioPath) async {
    pronunciations[word] = WordPronunciation(
      id: wordPronunciationId(word),
      word: word,
      audioUrl: audioPath,
      lastUpdated: DateTime(2025),
    );
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
    analyses[sentence] = SentenceAnalysis(
      id: 0,
      sentence: sentence,
      analysis: analysis,
      lastUpdated: DateTime(2025),
    );
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
    pronunciations[sentence] = SentencePronunciation(
      id: sentencePronunciationId(sentence),
      sentence: sentence,
      audioUrl: audioPath,
      lastUpdated: DateTime(2025),
    );
  }
}

class FakeFreeDictionaryService extends FreeDictionaryService {
  FakeFreeDictionaryService({required this.audioBytes}) : super(dio: testDio());

  final List<int> audioBytes;

  @override
  Future<List<int>?> getPronunciationAudio(
    String word, {
    LearningCancellation? cancellation,
  }) async => audioBytes;
}

class ThrowingFreeDictionaryService extends FreeDictionaryService {
  ThrowingFreeDictionaryService(this.error) : super(dio: testDio());

  final Object error;

  @override
  Future<List<int>?> getPronunciationAudio(
    String word, {
    LearningCancellation? cancellation,
  }) async {
    throw error;
  }
}

Dio testDio() {
  final dio = Dio();
  addTearDown(() => dio.close(force: true));
  return dio;
}

class FakeDeepSeekService extends DeepSeekService {
  FakeDeepSeekService({
    this.wordChunks = const <String>[],
    this.sentenceChunks = const <String>[],
  }) : super(dio: testDio());

  final List<String> wordChunks;
  final List<String> sentenceChunks;

  @override
  Stream<String> explainWordStream(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) async* {
    yield* Stream<String>.fromIterable(wordChunks);
  }

  @override
  Stream<String> analyzeSentenceStream(
    String sentence, {
    LearningCancellation? cancellation,
  }) async* {
    yield* Stream<String>.fromIterable(sentenceChunks);
  }
}

class FakeAliyunTTSService extends AliyunTTSService {
  FakeAliyunTTSService(this.chunks) : super(dio: testDio());

  final List<List<int>> chunks;

  @override
  Stream<List<int>> generateAudioStream(
    String text, {
    LearningCancellation? cancellation,
  }) async* {
    yield* Stream<List<int>>.fromIterable(chunks);
  }
}

class TestPathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  TestPathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
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
          explanation: wordDefinitionContent,
        );

        final repository = WordRepository(
          FreeDictionaryService(dio: testDio()),
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          cacheStore,
          InMemoryAudioFileStore(),
        );

        final result = await repository.getInfo(
          const WordLearningQuery(word: word, context: context),
        );

        expect(result.content, wordDefinitionContent);
        expect(result.audioUrl, isNull);
        expect(result.hasCachedContent, isTrue);
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
          FreeDictionaryService(dio: testDio()),
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          cacheStore,
          InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/clarity.wav'}),
        );

        final result = await repository.getInfo(
          const WordLearningQuery(word: word, context: context),
        );

        expect(result.content, isNull);
        expect(result.audioUrl, '/tmp/clarity.wav');
        expect(result.hasCachedContent, isFalse);
        expect(result.hasCachedAudio, isTrue);
      },
    );

    test('returns both caches when explanation and audio both exist', () async {
      const word = 'clarity';
      const context = 'Clarity matters.';

      await cacheStore.saveExplanation(
        word: word,
        context: context,
        explanation: wordDefinitionContent,
      );
      await cacheStore.savePronunciationPath(word, '/tmp/clarity.wav');

      final repository = WordRepository(
        FreeDictionaryService(dio: testDio()),
        DeepSeekService(dio: testDio()),
        AliyunTTSService(dio: testDio()),
        cacheStore,
        InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/clarity.wav'}),
      );

      final result = await repository.getInfo(
        const WordLearningQuery(word: word, context: context),
      );

      expect(result.content, wordDefinitionContent);
      expect(result.audioUrl, '/tmp/clarity.wav');
      expect(result.hasCachedContent, isTrue);
      expect(result.hasCachedAudio, isTrue);
      expect(result.isFullyCached, isTrue);
    });

    test(
      'persists resolved word audio path back into pronunciation cache',
      () async {
        const word = 'clarity';
        const context = 'Clarity matters.';

        await cacheStore.savePronunciationPath(word, '/tmp/stale.wav');

        final repository = WordRepository(
          FreeDictionaryService(dio: testDio()),
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          cacheStore,
          InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/fresh.wav'}),
        );

        final result = await repository.getInfo(
          const WordLearningQuery(word: word, context: context),
        );

        expect(result.audioUrl, '/tmp/fresh.wav');
        expect(cacheStore.pronunciations[word]?.audioUrl, '/tmp/fresh.wav');
      },
    );

    test('完整词典 MP3 使用本地缓存播放且不绑定 TTS 音色', () async {
      const word = 'clarity';
      final repository = WordRepository(
        FakeFreeDictionaryService(audioBytes: const <int>[1, 2, 3, 4]),
        DeepSeekService(dio: testDio()),
        AliyunTTSService(dio: testDio()),
        cacheStore,
        InMemoryAudioFileStore(),
      );

      final result = await repository.getPronunciationStream(word).first;

      expect(result.format, AudioFormat.mp3);
      expect(result.playbackUri, isNull);
      expect(result.cacheByVoice, isFalse);
      expect(await result.stream.expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
    });

    test('falls back to aliyun pcm when dictionary lookup fails', () async {
      const word = 'clarity';
      final repository = WordRepository(
        ThrowingFreeDictionaryService(Exception('dictionary failed')),
        DeepSeekService(dio: testDio()),
        FakeAliyunTTSService(const <List<int>>[
          <int>[1, 2],
          <int>[3, 4],
        ]),
        cacheStore,
        InMemoryAudioFileStore(),
      );

      final result = await repository.getPronunciationStream(word).first;

      expect(result.format, AudioFormat.pcm);
      expect(result.playbackUri, isNull);
      expect(result.sampleRate, 24000);
      expect(result.numChannels, 1);
      expect(result.bitsPerSample, 16);
      expect(await result.stream.expand((chunk) => chunk).toList(), <int>[
        1,
        2,
        3,
        4,
      ]);
    });

    test('persists full explanation after word stream completes', () async {
      const word = 'clarity';
      const context = 'Clarity matters.';
      final repository = WordRepository(
        FreeDictionaryService(dio: testDio()),
        FakeDeepSeekService(wordChunks: wordDefinitionContent.split('')),
        AliyunTTSService(dio: testDio()),
        cacheStore,
        InMemoryAudioFileStore(),
      );

      final chunks = await repository
          .getContentStream(
            const WordLearningQuery(word: word, context: context),
          )
          .toList();

      expect(chunks, wordDefinitionRecords);
      expect(
        cacheStore.explanations['$word|$context']?.explanation,
        wordDefinitionContent,
      );
    });
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
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(),
        );

        final result = await repository.getInfo(
          const SentenceLearningQuery(sentence: sentence),
        );

        expect(result.content, 'cached analysis');
        expect(result.audioUrl, isNull);
        expect(result.hasCachedContent, isTrue);
        expect(result.hasCachedAudio, isFalse);
      },
    );

    test(
      'returns only audio cache when pronunciation exists and analysis is missing',
      () async {
        const sentence = 'Clarity matters.';

        await pronunciationStore.saveAudioPath(sentence, '/tmp/sentence.wav');

        final repository = SentenceRepository(
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(
            sentenceAudioPaths: {sentence: '/tmp/sentence.wav'},
          ),
        );

        final result = await repository.getInfo(
          const SentenceLearningQuery(sentence: sentence),
        );

        expect(result.content, isNull);
        expect(result.audioUrl, '/tmp/sentence.wav');
        expect(result.hasCachedContent, isFalse);
        expect(result.hasCachedAudio, isTrue);
      },
    );

    test('returns both caches when analysis and audio both exist', () async {
      const sentence = 'Clarity matters.';

      await analysisStore.saveAnalysis(
        sentence: sentence,
        analysis: 'cached analysis',
      );
      await pronunciationStore.saveAudioPath(sentence, '/tmp/sentence.wav');

      final repository = SentenceRepository(
        DeepSeekService(dio: testDio()),
        AliyunTTSService(dio: testDio()),
        analysisStore,
        pronunciationStore,
        InMemoryAudioFileStore(
          sentenceAudioPaths: {sentence: '/tmp/sentence.wav'},
        ),
      );

      final result = await repository.getInfo(
        const SentenceLearningQuery(sentence: sentence),
      );

      expect(result.content, 'cached analysis');
      expect(result.audioUrl, '/tmp/sentence.wav');
      expect(result.hasCachedContent, isTrue);
      expect(result.hasCachedAudio, isTrue);
      expect(result.isFullyCached, isTrue);
    });

    test(
      'persists resolved sentence audio path back into pronunciation cache',
      () async {
        const sentence = 'Clarity matters.';

        await pronunciationStore.saveAudioPath(sentence, '/tmp/stale.wav');

        final repository = SentenceRepository(
          DeepSeekService(dio: testDio()),
          AliyunTTSService(dio: testDio()),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(
            sentenceAudioPaths: {sentence: '/tmp/fresh.wav'},
          ),
        );

        final result = await repository.getInfo(
          const SentenceLearningQuery(sentence: sentence),
        );

        expect(result.audioUrl, '/tmp/fresh.wav');
        expect(
          pronunciationStore.pronunciations[sentence]?.audioUrl,
          '/tmp/fresh.wav',
        );
      },
    );

    test('returns pcm stream metadata for sentence pronunciation', () async {
      const sentence = 'Clarity matters.';
      final repository = SentenceRepository(
        DeepSeekService(dio: testDio()),
        FakeAliyunTTSService(const <List<int>>[
          <int>[5, 6],
          <int>[7, 8],
        ]),
        analysisStore,
        pronunciationStore,
        InMemoryAudioFileStore(),
      );

      final result = await repository.getPronunciationStream(sentence).first;

      expect(result.format, AudioFormat.pcm);
      expect(result.playbackUri, isNull);
      expect(result.sampleRate, 24000);
      expect(result.numChannels, 1);
      expect(result.bitsPerSample, 16);
      expect(await result.stream.expand((chunk) => chunk).toList(), <int>[
        5,
        6,
        7,
        8,
      ]);
    });

    test('persists full analysis after sentence stream completes', () async {
      const sentence = 'Clarity matters.';
      final repository = SentenceRepository(
        FakeDeepSeekService(
          sentenceChunks: const <String>['translation', '\n', 'analysis'],
        ),
        AliyunTTSService(dio: testDio()),
        analysisStore,
        pronunciationStore,
        InMemoryAudioFileStore(),
      );

      final chunks = await repository
          .getContentStream(const SentenceLearningQuery(sentence: sentence))
          .toList();

      expect(chunks, <String>['translation', '\n', 'analysis']);
      expect(
        analysisStore.analyses[sentence]?.analysis,
        'translation\nanalysis',
      );
    });
  });

  group('Aliyun TTS persistence', () {
    late PathProviderPlatform originalPathProvider;
    late Directory tempDir;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;
      tempDir = await Directory.systemTemp.createTemp('synlen_learning_test_');
      PathProviderPlatform.instance = TestPathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'sentence aliyun pcm bytes stay identical after session buffering and file save',
      () async {
        const sentence = 'Clarity matters.';
        const originalBytes = <int>[1, 2, 3, 4, 5, 6, 7, 8];
        final repository = SentenceRepository(
          DeepSeekService(dio: testDio()),
          FakeAliyunTTSService(const <List<int>>[
            <int>[1, 2, 3],
            <int>[4, 5],
            <int>[6, 7, 8],
          ]),
          InMemorySentenceAnalysisStore(),
          InMemorySentencePronunciationStore(),
          const LearningAudioFileStore(),
        );

        final result = await repository.getPronunciationStream(sentence).first;
        final session = LearningStreamingAudioSession(result: result);
        final bufferedBytes = await session.waitForPlayableFileBytes();
        final filePath = await repository.saveAudioFile(
          sentence,
          bufferedBytes,
          result.format,
          cacheByVoice: result.cacheByVoice,
        );
        final savedBytes = await File(filePath).readAsBytes();

        expect(result.format, AudioFormat.pcm);
        expect(bufferedBytes, originalBytes);
        expect(savedBytes, originalBytes);
      },
    );

    test(
      'word aliyun fallback pcm bytes stay identical after session buffering and file save',
      () async {
        const word = 'clarity';
        const originalBytes = <int>[11, 22, 33, 44, 55, 66];
        final repository = WordRepository(
          ThrowingFreeDictionaryService(Exception('dictionary failed')),
          DeepSeekService(dio: testDio()),
          FakeAliyunTTSService(const <List<int>>[
            <int>[11, 22],
            <int>[33],
            <int>[44, 55, 66],
          ]),
          InMemoryWordCacheStore(),
          const LearningAudioFileStore(),
        );

        final result = await repository.getPronunciationStream(word).first;
        final session = LearningStreamingAudioSession(result: result);
        final bufferedBytes = await session.waitForPlayableFileBytes();
        final filePath = await repository.saveAudioFile(
          word,
          bufferedBytes,
          result.format,
          cacheByVoice: result.cacheByVoice,
        );
        final savedBytes = await File(filePath).readAsBytes();

        expect(result.format, AudioFormat.pcm);
        expect(bufferedBytes, originalBytes);
        expect(savedBytes, originalBytes);
      },
    );
  });
}
