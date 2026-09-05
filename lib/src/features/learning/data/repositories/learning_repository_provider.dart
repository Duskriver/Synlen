import 'package:dio/dio.dart';
import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/settings/application/api_key_notifier.dart';
import 'package:synlen/src/features/settings/application/tts_voice_notifier.dart';

import 'word_repository.dart';
import 'sentence_repository.dart';

part 'learning_repository_provider.g.dart';

// --- Services Providers ---

/// 提供 [FreeDictionaryService] 实例
@riverpod
FreeDictionaryService freeDictionaryService(Ref ref) {
  final dio = _createDio(ref);
  return FreeDictionaryService(dio: dio);
}

/// 提供 [DeepSeekService] 实例
@riverpod
DeepSeekService deepSeekService(Ref ref) {
  final dio = _createDio(ref);
  return DeepSeekService(
    dio: dio,
    readApiKey: () async => (await ref.read(apiKeyProvider.future)).deepSeekKey,
  );
}

/// 提供 [AliyunTTSService] 实例
@riverpod
AliyunTTSService aliyunTTSService(Ref ref) {
  return AliyunTTSService(
    dio: _createDio(ref),
    readApiKey: () async =>
        (await ref.read(apiKeyProvider.future)).aliyunTtsKey,
    readVoiceParam: () => ref.read(ttsVoiceProvider).voiceParam,
  );
}

@riverpod
LearningAudioFileStore learningAudioFileStore(Ref ref) {
  return const LearningAudioFileStore();
}

@riverpod
WordLearningCacheStore wordLearningCacheStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return WordLearningCacheStore(db);
}

@riverpod
SentenceLearningCacheStore sentenceLearningCacheStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SentenceLearningCacheStore(db);
}

@riverpod
SentencePronunciationCacheStore sentencePronunciationCacheStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return SentencePronunciationCacheStore(db);
}

// --- Repository Providers ---

/// 提供 [WordRepository] 实例
@riverpod
WordRepository wordRepository(Ref ref) {
  final freeDictionaryService = ref.watch(freeDictionaryServiceProvider);
  final deepSeekService = ref.watch(deepSeekServiceProvider);
  final aliyunTTSService = ref.watch(aliyunTTSServiceProvider);
  final cacheStore = ref.watch(wordLearningCacheStoreProvider);
  final audioFileStore = ref.watch(learningAudioFileStoreProvider);

  return WordRepository(
    freeDictionaryService,
    deepSeekService,
    aliyunTTSService,
    cacheStore,
    audioFileStore,
  );
}

/// 提供 [SentenceRepository] 实例
@riverpod
SentenceRepository sentenceRepository(Ref ref) {
  final deepSeekService = ref.watch(deepSeekServiceProvider);
  final aliyunTTSService = ref.watch(aliyunTTSServiceProvider);
  final analysisCacheStore = ref.watch(sentenceLearningCacheStoreProvider);
  final pronunciationCacheStore = ref.watch(
    sentencePronunciationCacheStoreProvider,
  );
  final audioFileStore = ref.watch(learningAudioFileStoreProvider);

  return SentenceRepository(
    deepSeekService,
    aliyunTTSService,
    analysisCacheStore,
    pronunciationCacheStore,
    audioFileStore,
  );
}

Dio _createDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
}
