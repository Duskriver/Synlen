import '../services/learning_http_request.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:dio/dio.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

/// 单词学习结果
class WordLearningResult {
  /// 发音音频 URL (来自 API 或 TTS)
  final String? audioUrl;

  /// 单词解释 (Markdown 格式)
  final String? explanation;

  /// 是否是缓存结果
  final bool hasCachedExplanation;
  final bool hasCachedAudio;

  WordLearningResult({
    this.audioUrl,
    this.explanation,
    this.hasCachedExplanation = false,
    this.hasCachedAudio = false,
  });

  bool get isFullyCached => hasCachedExplanation && hasCachedAudio;
}

/// 单词学习仓库，专门负责单词的发音、解释及缓存逻辑
class WordRepository {
  final FreeDictionaryService _freeDictionaryService;
  final DeepSeekService _deepSeekService;
  final AliyunTTSService _aliyunTTSService;
  final WordCacheStore _cacheStore;
  final AudioFileStore _audioFileStore;

  WordRepository(
    this._freeDictionaryService,
    this._deepSeekService,
    this._aliyunTTSService,
    this._cacheStore,
    this._audioFileStore,
  );

  /// 从本地缓存获取单词信息
  Future<WordExplanation?> getCachedWord(String word, String context) {
    return _cacheStore.getExplanation(word, context);
  }

  /// 从本地缓存获取单词发音信息
  Future<WordPronunciation?> getCachedPronunciation(String word) {
    return _cacheStore.getPronunciation(word);
  }

  /// 获取单词的发音音频字节流结果（包含流和格式）
  ///
  /// 业务逻辑：
  /// 1. 首先尝试从免费词典 API 获取 URL (返回 mp3)
  /// 2. 如果成功，流式下载该 URL 的内容
  /// 3. 如果失败，降级调用阿里云 TTS 流式接口 (返回 pcm)
  Stream<AudioStreamResult> getPronunciationStream(
    String word, {
    LearningCancellation? cancellation,
  }) async* {
    final request = LearningHttpRequest(cancellation);
    var responseTransferred = false;
    try {
      cancellation?.throwIfCancelled();
      // 1. 尝试免费词典
      final dictionaryAudioUrl = await _freeDictionaryService
          .getPronunciationUrl(word, cancellation: cancellation);
      cancellation?.throwIfCancelled();
      if (dictionaryAudioUrl != null && dictionaryAudioUrl.isNotEmpty) {
        final response = await _freeDictionaryService.dio.get<ResponseBody>(
          dictionaryAudioUrl,
          cancelToken: request.cancelToken,
          options: Options(responseType: ResponseType.stream),
        );
        if (response.statusCode == 200 && response.data != null) {
          responseTransferred = true;
          yield AudioStreamResult(
            stream: request.bind(response.data!.stream.cast<List<int>>()),
            format: AudioFormat.mp3,
            cacheByVoice: false,
            playbackUri: dictionaryAudioUrl,
          );
          return;
        }
      }
    } catch (e) {
      cancellation?.throwIfCancelled();
      appLogger.w(
        'Free Dictionary Audio error, falling back to Aliyun TTS: $e',
      );
    } finally {
      if (!responseTransferred) request.dispose();
    }

    cancellation?.throwIfCancelled();
    // 2. 降级到阿里云 TTS 流式 (PCM)
    yield AudioStreamResult(
      stream: _aliyunTTSService.generateAudioStream(
        word,
        cancellation: cancellation,
      ),
      format: AudioFormat.pcm,
      cacheByVoice: true,
      sampleRate: 24000,
      numChannels: 1,
      bitsPerSample: 16,
    );
  }

  /// 获取单词基础信息
  ///
  /// [word] 目标单词
  /// [context] 上下文句子
  /// 返回 [WordLearningResult]，如果 explanation 为 null 且 isFromCache 为 false，
  /// UI 应并行启动 getWordExplanationStream 和 getPronunciationStream
  Future<WordLearningResult> getWordInfo(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final voice = _aliyunTTSService.currentVoiceParam;
    final cachedExplanation = await getCachedWord(word, context);
    final cachedPronunciation = await getCachedPronunciation(word);
    cancellation?.throwIfCancelled();
    final audioPath = await _audioFileStore.resolveWordAudioPath(
      word,
      preferredPath: cachedPronunciation?.audioUrl,
      voice: voice,
    );

    cancellation?.throwIfCancelled();
    if (audioPath != null &&
        (cachedPronunciation == null ||
            cachedPronunciation.audioUrl != audioPath)) {
      await persistAudioPath(word, audioPath);
    }

    return WordLearningResult(
      audioUrl: audioPath,
      explanation: cachedExplanation?.explanation,
      hasCachedExplanation: cachedExplanation?.explanation.isNotEmpty ?? false,
      hasCachedAudio: audioPath != null,
    );
  }

  /// 保存音频文件到本地并返回路径；保存后按容量预算清退最旧音频。
  Future<String> saveAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format, {
    required bool cacheByVoice,
  }) async {
    final path = await _audioFileStore.saveWordAudioFile(
      word,
      bytes,
      format,
      voice: _aliyunTTSService.currentVoiceParam,
      cacheByVoice: cacheByVoice,
    );
    await _audioFileStore.evictAudioCache();
    return path;
  }

  Future<void> persistAudioPath(String word, String audioPath) {
    return _cacheStore.savePronunciationPath(word, audioPath);
  }

  /// 流式获取单词解释并自动持久化
  Stream<String> getWordExplanationStream(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) async* {
    cancellation?.throwIfCancelled();
    String fullContent = '';

    // 同时启动 AI 查询
    final aiStream = _deepSeekService.explainWordStream(
      word,
      context,
      cancellation: cancellation,
    );

    await for (final chunk in aiStream) {
      fullContent += chunk;
      yield chunk;
    }

    cancellation?.throwIfCancelled();
    // 当 AI 解释完成时，保存到本地缓存
    if (fullContent.isNotEmpty) {
      await _cacheStore.saveExplanation(
        word: word,
        context: context,
        explanation: fullContent,
      );
    }
  }
}
