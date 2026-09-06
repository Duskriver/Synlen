import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';

import 'learning_cache_cleanup_service.dart';

part 'learning_cache_cleanup_service_provider.g.dart';

/// Provider for [LearningCacheCleanupService].
@riverpod
LearningCacheCleanupService learningCacheCleanupService(Ref ref) {
  return LearningCacheCleanupService(
    db: ref.watch(appDatabaseProvider),
    audioFileStore: const LearningAudioFileStore(),
  );
}
