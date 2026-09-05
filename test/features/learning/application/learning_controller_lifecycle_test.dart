import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import '../data/repositories/learning_repository_test.dart'
    show InMemoryWordCacheStore, InMemoryAudioFileStore, testDio;
import '../data/services/deep_seek_service_test.dart'
    show FakeChatAdapter, body;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/sentence_learning_controller.dart';
import 'package:synlen/src/features/learning/application/word_learning_controller.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;

class DeferredWordRepository implements WordRepository {
  final info = Completer<WordLearningResult>();
  final started = Completer<void>();
  final text = StreamController<String>();
  LearningCancellation? cancellation;
  void Function()? afterRead;

  @override
  Future<WordLearningResult> getWordInfo(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    started.complete();
    final result = await info.future;
    afterRead?.call();
    return result;
  }

  @override
  Stream<String> getWordExplanationStream(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) => text.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DeferredSentenceRepository implements SentenceRepository {
  final info = Completer<SentenceLearningResult>();
  final started = Completer<void>();
  final text = StreamController<String>();
  LearningCancellation? cancellation;
  void Function()? afterRead;

  @override
  Future<SentenceLearningResult> getSentenceInfo(
    String sentence, {
    LearningCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    started.complete();
    final result = await info.future;
    afterRead?.call();
    return result;
  }

  @override
  Stream<String> getSentenceAnalysisStream(
    String sentence, {
    LearningCancellation? cancellation,
  }) => text.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('单词：慢词典失败后真实 TTS 回退仍可读配置，并持久化完整音频', () async {
    final dictionaryDio = testDio();
    final ttsDio = testDio();
    final dictionaryResponse = Completer<ResponseBody>();
    final dictionaryAdapter = FakeChatAdapter((_) => dictionaryResponse.future);
    dictionaryDio.httpClientAdapter = dictionaryAdapter;
    ttsDio.httpClientAdapter = FakeChatAdapter(
      (_) async => body(
        'data: ${jsonEncode({
          'output': {
            'audio': {
              'data': base64Encode([0, 0, 1, 0]),
            },
          },
        })}\n\n',
      ),
    );
    final cache = InMemoryWordCacheStore();
    final audioFiles = InMemoryAudioFileStore();
    await cache.saveExplanation(
      word: 'word',
      context: 'context',
      explanation: '缓存释义',
    );
    final marker = Provider((_) => 'test-key');
    var serviceDisposed = false;
    var keyReads = 0;
    final container = ProviderContainer.test(
      overrides: [
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => FakeLearningAudioPlayer.new,
        ),
        freeDictionaryServiceProvider.overrideWith(
          (_) => FreeDictionaryService(dio: dictionaryDio),
        ),
        deepSeekServiceProvider.overrideWith(
          (_) => DeepSeekService(dio: testDio()),
        ),
        aliyunTTSServiceProvider.overrideWith((ref) {
          ref.onDispose(() => serviceDisposed = true);
          return AliyunTTSService(
            dio: ttsDio,
            readApiKey: () {
              keyReads++;
              return ref.read(marker);
            },
            readVoiceParam: () {
              ref.read(marker);
              return 'Cherry';
            },
          );
        }),
        wordRepositoryProvider.overrideWith(
          (ref) => WordRepository(
            ref.watch(freeDictionaryServiceProvider),
            ref.watch(deepSeekServiceProvider),
            ref.watch(aliyunTTSServiceProvider),
            cache,
            audioFiles,
          ),
        ),
      ],
    );
    final provider = wordLearningControllerProvider(
      const WordLearningRequest(word: 'word', context: 'context'),
    );
    final finished = Completer<void>();
    final subscription = container.listen(provider, (_, next) {
      if (!next.isLoading && !next.isFetchingAudio && !finished.isCompleted) {
        finished.complete();
      }
    });
    await dictionaryAdapter.started.future;
    await container.pump();
    expect(serviceDisposed, isFalse);
    dictionaryResponse.complete(ResponseBody.fromString('not found', 404));
    await finished.future.timeout(const Duration(seconds: 1));
    final state = container.read(provider);
    expect(state.content, '缓存释义');
    expect(state.audioError, isNull);
    expect(state.hasAudio, isTrue);
    expect(state.audioUrl, '/tmp/word.pcm');
    expect(cache.pronunciations['word']?.audioUrl, '/tmp/word.pcm');
    expect(keyReads, greaterThan(0));
    subscription.close();
    await container.pump();
    expect(serviceDisposed, isTrue);
  });

  final wordProvider = wordLearningControllerProvider(
    const WordLearningRequest(word: 'word', context: 'A word.'),
  );
  final sentenceProvider = sentenceLearningControllerProvider('A sentence.');

  for (final isWord in [true, false]) {
    final label = isWord ? '单词' : '句子';
    final provider = isWord ? wordProvider : sentenceProvider;

    test('$label：慢缓存查询期间持有 Repository，关闭后才释放', () async {
      final word = DeferredWordRepository();
      final sentence = DeferredSentenceRepository();
      var disposed = false;
      final marker = Provider((_) => 'still alive');
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          wordRepositoryProvider.overrideWith((ref) {
            ref.onDispose(() => disposed = true);
            word.afterRead = () => expect(ref.read(marker), 'still alive');
            return word;
          }),
          sentenceRepositoryProvider.overrideWith((ref) {
            ref.onDispose(() => disposed = true);
            sentence.afterRead = () => expect(ref.read(marker), 'still alive');
            return sentence;
          }),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await (isWord ? word.started.future : sentence.started.future);
      await container.pump();
      expect(disposed, isFalse);
      word.info.complete(
        WordLearningResult(
          explanation: '缓存',
          hasCachedExplanation: true,
          hasCachedAudio: true,
        ),
      );
      sentence.info.complete(
        SentenceLearningResult(
          analysis: '缓存',
          hasCachedAnalysis: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, '缓存');
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      expect(disposed, isTrue);
      expect(
        (isWord ? word.cancellation : sentence.cancellation)!.isCancelled,
        isTrue,
      );
      unawaited(word.text.close());
      unawaited(sentence.text.close());
    });

    test('$label：正文没有首包时关闭也立即取消订阅', () async {
      final word = DeferredWordRepository();
      final sentence = DeferredSentenceRepository();
      final source = isWord ? word.text : sentence.text;
      final listening = Completer<void>();
      final cancelled = Completer<void>();
      source.onListen = listening.complete;
      source.onCancel = cancelled.complete;
      word.info.complete(WordLearningResult(hasCachedAudio: true));
      sentence.info.complete(SentenceLearningResult(hasCachedAudio: true));
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          wordRepositoryProvider.overrideWith((_) => word),
          sentenceRepositoryProvider.overrideWith((_) => sentence),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await listening.future;
      subscription.close();
      await container.pump();
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(
        (isWord ? word.cancellation : sentence.cancellation)!.isCancelled,
        isTrue,
      );
      unawaited(word.text.close());
      unawaited(sentence.text.close());
    });

    test('$label：依赖重建后旧缓存结果不得覆盖新查询', () async {
      final oldWord = DeferredWordRepository();
      final oldSentence = DeferredSentenceRepository();
      final newWord = DeferredWordRepository();
      final newSentence = DeferredSentenceRepository();
      var generation = 0;
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          wordRepositoryProvider.overrideWith(
            (_) => generation == 0 ? oldWord : newWord,
          ),
          sentenceRepositoryProvider.overrideWith(
            (_) => generation == 0 ? oldSentence : newSentence,
          ),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await (isWord ? oldWord.started.future : oldSentence.started.future);
      generation++;
      if (isWord) {
        container.invalidate(wordRepositoryProvider);
      } else {
        container.invalidate(sentenceRepositoryProvider);
      }
      await container.pump();
      await (isWord ? newWord.started.future : newSentence.started.future);
      expect(
        (isWord ? oldWord.cancellation : oldSentence.cancellation)!.isCancelled,
        isTrue,
      );
      newWord.info.complete(
        WordLearningResult(
          explanation: '新查询',
          hasCachedExplanation: true,
          hasCachedAudio: true,
        ),
      );
      newSentence.info.complete(
        SentenceLearningResult(
          analysis: '新查询',
          hasCachedAnalysis: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, '新查询');
      oldWord.info.complete(
        WordLearningResult(
          explanation: '旧查询',
          hasCachedExplanation: true,
          hasCachedAudio: true,
        ),
      );
      oldSentence.info.complete(
        SentenceLearningResult(
          analysis: '旧查询',
          hasCachedAnalysis: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, '新查询');
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      for (final source in [
        oldWord.text,
        oldSentence.text,
        newWord.text,
        newSentence.text,
      ]) {
        unawaited(source.close());
      }
    });
  }
}
