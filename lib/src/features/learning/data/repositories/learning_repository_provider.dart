import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'word_repository.dart';
import 'sentence_repository.dart';

part 'learning_repository_provider.g.dart';

// --- Services Providers ---

/// 提供 [FreeDictionaryService] 实例
@riverpod
FreeDictionaryService freeDictionaryService(FreeDictionaryServiceRef ref) {
  return FreeDictionaryService();
}

/// 提供 [DeepSeekService] 实例
@riverpod
DeepSeekService deepSeekService(DeepSeekServiceRef ref) {
  return DeepSeekService();
}

/// 提供 [AliyunTTSService] 实例
@riverpod
AliyunTTSService aliyunTTSService(AliyunTTSServiceRef ref) {
  return AliyunTTSService();
}

@riverpod
LearningAudioFileStore learningAudioFileStore(LearningAudioFileStoreRef ref) {
  return const LearningAudioFileStore();
}

@riverpod
WordLearningCacheStore wordLearningCacheStore(WordLearningCacheStoreRef ref) {
  final isar = ref.watch(isarProvider).requireValue;
  return WordLearningCacheStore(isar);
}

@riverpod
SentenceLearningCacheStore sentenceLearningCacheStore(
  SentenceLearningCacheStoreRef ref,
) {
  final isar = ref.watch(isarProvider).requireValue;
  return SentenceLearningCacheStore(isar);
}

@riverpod
SentencePronunciationCacheStore sentencePronunciationCacheStore(
  SentencePronunciationCacheStoreRef ref,
) {
  final isar = ref.watch(isarProvider).requireValue;
  return SentencePronunciationCacheStore(isar);
}

// --- Repository Providers ---

/// 提供 [WordRepository] 实例
@riverpod
WordRepository wordRepository(WordRepositoryRef ref) {
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
SentenceRepository sentenceRepository(SentenceRepositoryRef ref) {
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
