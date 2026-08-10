import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

/// 句子学习结果
class SentenceLearningResult {
  /// 句子语法和成分分析 (Markdown 格式)
  final String? analysis;

  /// 句子朗读音频文件路径 (来自 TTS)
  final String? audioUrl;

  /// 是否是缓存结果
  final bool hasCachedAnalysis;
  final bool hasCachedAudio;

  SentenceLearningResult({
    this.analysis,
    this.audioUrl,
    this.hasCachedAnalysis = false,
    this.hasCachedAudio = false,
  });

  bool get isFullyCached => hasCachedAnalysis && hasCachedAudio;
}

/// 句子学习仓库，专门负责句子的语法分析、TTS 朗读及缓存逻辑
class SentenceRepository {
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
  /// [sentence] 目标句子
  /// 返回 [SentenceLearningResult]，如果 analysis 为 null 且 isFromCache 为 false，
  /// UI 应并行启动 getSentenceAnalysisStream 和 getPronunciationStream
  Future<SentenceLearningResult> getSentenceInfo(String sentence) async {
    final cachedAnalysis = await getCachedSentence(sentence);
    final cachedPronunciation = await getCachedPronunciation(sentence);
    final voice = _aliyunTTSService.currentVoiceParam;
    final cachedAudioPath = await _audioFileStore.resolveSentenceAudioPath(
      sentence,
      preferredPath: cachedPronunciation?.audioUrl,
      voice: voice,
    );

    if (cachedAudioPath != null &&
        (cachedPronunciation == null ||
            cachedPronunciation.audioUrl != cachedAudioPath)) {
      await persistAudioPath(sentence, cachedAudioPath);
    }

    return SentenceLearningResult(
      analysis: cachedAnalysis?.analysis,
      audioUrl: cachedAudioPath,
      hasCachedAnalysis: cachedAnalysis?.analysis.isNotEmpty ?? false,
      hasCachedAudio: cachedAudioPath != null,
    );
  }

  /// 获取句子的发音音频字节流结果 (PCM)
  Stream<AudioStreamResult> getPronunciationStream(String sentence) async* {
    yield AudioStreamResult(
      stream: _aliyunTTSService.generateAudioStream(sentence),
      format: AudioFormat.pcm,
      cacheByVoice: true,
      sampleRate: 24000,
      numChannels: 1,
      bitsPerSample: 16,
    );
  }

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(
    String sentence,
    List<int> bytes,
    AudioFormat format, {
    required bool cacheByVoice,
  }) {
    assert(cacheByVoice);
    return _audioFileStore.saveSentenceAudioFile(
      sentence,
      bytes,
      format,
      voice: _aliyunTTSService.currentVoiceParam,
    );
  }

  Future<void> persistAudioPath(String sentence, String audioPath) {
    return _pronunciationCacheStore.saveAudioPath(sentence, audioPath);
  }

  /// 流式获取句子分析并自动持久化
  Stream<String> getSentenceAnalysisStream(String sentence) async* {
    String fullContent = '';

    // 调用 DeepSeek AI 进行句子分析
    await for (final chunk in _deepSeekService.analyzeSentenceStream(
      sentence,
    )) {
      fullContent += chunk;
      yield chunk;
    }

    // 当 AI 分析流结束且内容有效时，保存到本地缓存
    if (fullContent.isNotEmpty) {
      await _analysisCacheStore.saveAnalysis(
        sentence: sentence,
        analysis: fullContent,
      );
    }
  }
}
