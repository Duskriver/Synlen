import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';

/// 学习缓存清理：学习文本缓存表与 TTS 音频文件均为可重建数据，
/// 删除不影响用户图书与阅读进度。
class LearningCacheCleanupService {
  final AppDatabase _db;
  final AudioFileStore _audioFileStore;

  LearningCacheCleanupService({
    required AppDatabase db,
    required AudioFileStore audioFileStore,
  }) : _db = db,
       _audioFileStore = audioFileStore;

  /// 清空学习文本缓存表与全部音频缓存，返回删除的音频文件数。
  Future<int> cleanAll() async {
    await _db.delete(_db.wordExplanations).go();
    await _db.delete(_db.wordPronunciations).go();
    await _db.delete(_db.sentenceAnalyses).go();
    await _db.delete(_db.sentencePronunciations).go();
    return _audioFileStore.evictAudioCache(maxBytes: 0);
  }
}
