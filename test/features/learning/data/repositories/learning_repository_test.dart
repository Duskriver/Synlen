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
import 'package:synlen/src/core/database/app_database.dart';

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
  FakeFreeDictionaryService({
    required this.pronunciationUrl,
    required this.audioBytes,
  }) : _dio = Dio() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<ResponseBody>(
              requestOptions: options,
              statusCode: 200,
              data: ResponseBody.fromBytes(
                audioBytes,
                200,
                headers: {
                  Headers.contentTypeHeader: const <String>['audio/mpeg'],
                },
              ),
            ),
          );
        },
      ),
    );
  }

  final String pronunciationUrl;
  final List<int> audioBytes;
  final Dio _dio;

  @override
  Dio get dio => _dio;

  @override
  Future<String?> getPronunciationUrl(String word) async => pronunciationUrl;
}

class ThrowingFreeDictionaryService extends FreeDictionaryService {
  ThrowingFreeDictionaryService(this.error);

  final Object error;

  @override
  Future<String?> getPronunciationUrl(String word) async {
    throw error;
  }
}

class FakeDeepSeekService extends DeepSeekService {
  FakeDeepSeekService({
    this.wordChunks = const <String>[],
    this.sentenceChunks = const <String>[],
  });

  final List<String> wordChunks;
  final List<String> sentenceChunks;

  @override
  Stream<String> explainWordStream(String word, String context) async* {
    yield* Stream<String>.fromIterable(wordChunks);
  }

  @override
  Stream<String> analyzeSentenceStream(String sentence) async* {
    yield* Stream<String>.fromIterable(sentenceChunks);
  }
}

class FakeAliyunTTSService extends AliyunTTSService {
  FakeAliyunTTSService(this.chunks);

  final List<List<int>> chunks;

  @override
  Stream<List<int>> generateAudioStream(String text) async* {
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

    test('returns both caches when explanation and audio both exist', () async {
      const word = 'clarity';
      const context = 'Clarity matters.';

      await cacheStore.saveExplanation(
        word: word,
        context: context,
        explanation: 'cached explanation',
      );
      await cacheStore.savePronunciationPath(word, '/tmp/clarity.wav');

      final repository = WordRepository(
        FreeDictionaryService(),
        DeepSeekService(),
        AliyunTTSService(),
        cacheStore,
        InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/clarity.wav'}),
      );

      final result = await repository.getWordInfo(word, context);

      expect(result.explanation, 'cached explanation');
      expect(result.audioUrl, '/tmp/clarity.wav');
      expect(result.hasCachedExplanation, isTrue);
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
          FreeDictionaryService(),
          DeepSeekService(),
          AliyunTTSService(),
          cacheStore,
          InMemoryAudioFileStore(wordAudioPaths: {word: '/tmp/fresh.wav'}),
        );

        final result = await repository.getWordInfo(word, context);

        expect(result.audioUrl, '/tmp/fresh.wav');
        expect(cacheStore.pronunciations[word]?.audioUrl, '/tmp/fresh.wav');
      },
    );

    test(
      'dictionary mp3 exposes playback uri before caching completes',
      () async {
        const word = 'clarity';
        const url = 'https://example.com/audio/clarity.mp3';

        final repository = WordRepository(
          FakeFreeDictionaryService(
            pronunciationUrl: url,
            audioBytes: const <int>[1, 2, 3, 4],
          ),
          DeepSeekService(),
          AliyunTTSService(),
          cacheStore,
          InMemoryAudioFileStore(),
        );

        final result = await repository.getPronunciationStream(word).first;

        expect(result.format, AudioFormat.mp3);
        expect(result.playbackUri, url);
        expect(await result.stream.expand((chunk) => chunk).toList(), <int>[
          1,
          2,
          3,
          4,
        ]);
      },
    );

    test('falls back to aliyun pcm when dictionary lookup fails', () async {
      const word = 'clarity';
      final repository = WordRepository(
        ThrowingFreeDictionaryService(Exception('dictionary failed')),
        DeepSeekService(),
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
        FreeDictionaryService(),
        FakeDeepSeekService(wordChunks: const <String>['clear', ' ', 'idea']),
        AliyunTTSService(),
        cacheStore,
        InMemoryAudioFileStore(),
      );

      final chunks = await repository
          .getWordExplanationStream(word, context)
          .toList();

      expect(chunks, <String>['clear', ' ', 'idea']);
      expect(
        cacheStore.explanations['$word|$context']?.explanation,
        'clear idea',
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

    test('returns both caches when analysis and audio both exist', () async {
      const sentence = 'Clarity matters.';

      await analysisStore.saveAnalysis(
        sentence: sentence,
        analysis: 'cached analysis',
      );
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

      expect(result.analysis, 'cached analysis');
      expect(result.audioUrl, '/tmp/sentence.wav');
      expect(result.hasCachedAnalysis, isTrue);
      expect(result.hasCachedAudio, isTrue);
      expect(result.isFullyCached, isTrue);
    });

    test(
      'persists resolved sentence audio path back into pronunciation cache',
      () async {
        const sentence = 'Clarity matters.';

        await pronunciationStore.saveAudioPath(sentence, '/tmp/stale.wav');

        final repository = SentenceRepository(
          DeepSeekService(),
          AliyunTTSService(),
          analysisStore,
          pronunciationStore,
          InMemoryAudioFileStore(
            sentenceAudioPaths: {sentence: '/tmp/fresh.wav'},
          ),
        );

        final result = await repository.getSentenceInfo(sentence);

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
        DeepSeekService(),
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
        AliyunTTSService(),
        analysisStore,
        pronunciationStore,
        InMemoryAudioFileStore(),
      );

      final chunks = await repository
          .getSentenceAnalysisStream(sentence)
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
          DeepSeekService(),
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
          DeepSeekService(),
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
