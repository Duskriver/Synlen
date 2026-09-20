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
import 'package:synlen/src/features/learning/application/learning_controller.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';

import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;
import '../word_definition_fixture.dart';

class DeferredLearningRepository implements LearningRepository {
  final info = Completer<LearningInfo>();
  final started = Completer<void>();
  final text = StreamController<String>();
  LearningCancellation? cancellation;
  void Function()? afterRead;

  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    started.complete();
    final result = await info.future;
    afterRead?.call();
    return result;
  }

  @override
  Stream<String> getContentStream(
    LearningQuery query, {
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
      explanation: wordDefinitionContent,
    );
    final marker = Provider((_) => 'test-key');
    var serviceDisposed = false;
    var keyReads = 0;
    const query = WordLearningQuery(word: 'word', context: 'context');
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
        learningRepositoryProvider(query).overrideWith(
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
    final provider = learningControllerProvider(query);
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
    expect(state.content, wordDefinitionContent);
    expect(state.audioError, isNull);
    expect(state.hasAudio, isTrue);
    expect(state.audioUrl, '/tmp/word.pcm');
    expect(cache.pronunciations['word']?.audioUrl, '/tmp/word.pcm');
    expect(keyReads, greaterThan(0));
    subscription.close();
    await container.pump();
    expect(serviceDisposed, isTrue);
  });

  const wordQuery = WordLearningQuery(word: 'word', context: 'A word.');
  const sentenceQuery = SentenceLearningQuery(sentence: 'A sentence.');

  for (final isWord in [true, false]) {
    final label = isWord ? '单词' : '句子';
    final query = isWord ? wordQuery : sentenceQuery;
    final cachedContent = isWord ? wordDefinitionContent : '缓存';
    final newContent = isWord
        ? wordDefinitionContent.replaceFirst('分类', '新查询')
        : '新查询';
    final oldContent = isWord
        ? wordDefinitionContent.replaceFirst('分类', '旧查询')
        : '旧查询';
    final provider = learningControllerProvider(query);

    test('$label：慢缓存查询期间持有 Repository，关闭后才释放', () async {
      final repository = DeferredLearningRepository();
      var disposed = false;
      final marker = Provider((_) => 'still alive');
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          learningRepositoryProvider(query).overrideWith((ref) {
            ref.onDispose(() => disposed = true);
            repository.afterRead = () =>
                expect(ref.read(marker), 'still alive');
            return repository;
          }),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await repository.started.future;
      await container.pump();
      expect(disposed, isFalse);
      repository.info.complete(
        LearningInfo(
          content: cachedContent,
          hasCachedContent: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, cachedContent);
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      expect(disposed, isTrue);
      expect(repository.cancellation!.isCancelled, isTrue);
      unawaited(repository.text.close());
    });

    test('$label：正文没有首包时关闭也立即取消订阅', () async {
      final repository = DeferredLearningRepository();
      final listening = Completer<void>();
      final cancelled = Completer<void>();
      repository.text.onListen = listening.complete;
      repository.text.onCancel = cancelled.complete;
      repository.info.complete(const LearningInfo(hasCachedAudio: true));
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          learningRepositoryProvider(query).overrideWith((_) => repository),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await listening.future;
      subscription.close();
      await container.pump();
      await cancelled.future.timeout(const Duration(seconds: 1));
      expect(repository.cancellation!.isCancelled, isTrue);
      unawaited(repository.text.close());
    });

    test('$label：依赖重建后旧缓存结果不得覆盖新查询', () async {
      final oldRepository = DeferredLearningRepository();
      final newRepository = DeferredLearningRepository();
      var generation = 0;
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          learningRepositoryProvider(query).overrideWith(
            (_) => generation == 0 ? oldRepository : newRepository,
          ),
        ],
      );
      final subscription = container.listen(provider, (_, _) {});
      await oldRepository.started.future;
      generation++;
      container.invalidate(learningRepositoryProvider(query));
      await container.pump();
      await newRepository.started.future;
      expect(oldRepository.cancellation!.isCancelled, isTrue);
      newRepository.info.complete(
        LearningInfo(
          content: newContent,
          hasCachedContent: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, newContent);
      oldRepository.info.complete(
        LearningInfo(
          content: oldContent,
          hasCachedContent: true,
          hasCachedAudio: true,
        ),
      );
      await container.pump();
      expect(container.read(provider).content, newContent);
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      for (final source in [oldRepository.text, newRepository.text]) {
        unawaited(source.close());
      }
    });
  }
}
