import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';

/// 句子学习仓库，专门负责句子的语法分析、TTS 朗读及缓存逻辑
class SentenceRepository implements LearningRepository {
  final DeepSeekService _deepSeekService;
  final AliyunTTSService _aliyunTTSService;
  final SentenceAnalysisStore _analysisCacheStore;
  final SentencePronunciationStore _pronunciationCacheStore;
  final AudioFileStore _audioFileStore;

  SentenceRepository(
    this._deepSeekService,
    this._aliyunTTSService,
    this._analysisCacheStore,
    this._pronunciationCacheStore,
    this._audioFileStore,
  );

  /// 从本地缓存获取句子分析信息
  Future<SentenceAnalysis?> getCachedSentence(String sentence) {
    return _analysisCacheStore.getSentence(sentence);
  }

  Future<SentencePronunciation?> getCachedPronunciation(String sentence) {
    return _pronunciationCacheStore.getPronunciation(sentence);
  }

  /// 获取句子基础信息
  ///
  /// 返回 [LearningInfo]，如果 content 为 null 且 hasCachedContent 为 false，
  /// UI 应并行启动 getContentStream 和 getPronunciationStream
  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async {
    final sentence = (query as SentenceLearningQuery).sentence;
    cancellation?.throwIfCancelled();
    final voice = _aliyunTTSService.currentVoiceParam;
    final cachedAnalysis = await getCachedSentence(sentence);
    final cachedPronunciation = await getCachedPronunciation(sentence);
    cancellation?.throwIfCancelled();
    final cachedAudioPath = await _audioFileStore.resolveSentenceAudioPath(
      sentence,
      preferredPath: cachedPronunciation?.audioUrl,
      voice: voice,
    );

    cancellation?.throwIfCancelled();
    if (cachedAudioPath != null &&
        (cachedPronunciation == null ||
            cachedPronunciation.audioUrl != cachedAudioPath)) {
      await persistAudioPath(sentence, cachedAudioPath);
    }

    return LearningInfo(
      content: cachedAnalysis?.analysis,
      audioUrl: cachedAudioPath,
      hasCachedContent: cachedAnalysis?.analysis.isNotEmpty ?? false,
      hasCachedAudio: cachedAudioPath != null,
    );
  }

  /// 获取句子的发音音频字节流结果 (PCM)
  @override
  Stream<AudioStreamResult> getPronunciationStream(
    String sentence, {
    LearningCancellation? cancellation,
  }) async* {
    cancellation?.throwIfCancelled();
    yield AudioStreamResult(
      stream: _aliyunTTSService.generateAudioStream(
        sentence,
        cancellation: cancellation,
      ),
      format: AudioFormat.pcm,
      cacheByVoice: true,
      sampleRate: 24000,
      numChannels: 1,
      bitsPerSample: 16,
    );
  }

  /// 保存音频文件到本地并返回路径；保存后按容量预算清退最旧音频。
  @override
  Future<String> saveAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format, {
    required bool cacheByVoice,
  }) async {
    assert(cacheByVoice);
    final path = await _audioFileStore.saveSentenceAudioFile(
      sentence,
      bytes,
      format,
      voice: _aliyunTTSService.currentVoiceParam,
    );
    await _audioFileStore.evictAudioCache();
    return path;
  }

  @override
  Future<void> persistAudioPath(String sentence, String audioPath) {
    return _pronunciationCacheStore.saveAudioPath(sentence, audioPath);
  }

  /// 流式获取句子分析并自动持久化
  @override
  Stream<String> getContentStream(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async* {
    final sentence = (query as SentenceLearningQuery).sentence;
    cancellation?.throwIfCancelled();
    String fullContent = '';

    // 调用 DeepSeek AI 进行句子分析
    await for (final chunk in _deepSeekService.analyzeSentenceStream(
      sentence,
      cancellation: cancellation,
    )) {
      fullContent += chunk;
      yield chunk;
    }

    cancellation?.throwIfCancelled();
    // 当 AI 分析流结束且内容有效时，保存到本地缓存
    if (fullContent.isNotEmpty) {
      await _analysisCacheStore.saveAnalysis(
        sentence: sentence,
        analysis: fullContent,
      );
    }
  }
}
