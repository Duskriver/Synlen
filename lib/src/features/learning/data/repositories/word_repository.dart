import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/word_explanation.dart';
import 'package:synlen/src/features/learning/domain/word_pronunciation.dart';

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
  Stream<AudioStreamResult> getPronunciationStream(String word) async* {
    try {
      // 1. 尝试免费词典
      final dictionaryAudioUrl = await _freeDictionaryService
          .getPronunciationUrl(word);
      if (dictionaryAudioUrl != null && dictionaryAudioUrl.isNotEmpty) {
        final response = await _freeDictionaryService.dio.get<ResponseBody>(
          dictionaryAudioUrl,
          options: Options(responseType: ResponseType.stream),
        );
        if (response.statusCode == 200 && response.data != null) {
          yield AudioStreamResult(
            stream: response.data!.stream.cast<List<int>>(),
            format: AudioFormat.mp3,
            playbackUri: dictionaryAudioUrl,
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('Free Dictionary Audio error, falling back to Aliyun TTS: $e');
    }

    // 2. 降级到阿里云 TTS 流式 (PCM)
    yield AudioStreamResult(
      stream: _aliyunTTSService.generateAudioStream(word),
      format: AudioFormat.pcm,
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
  Future<WordLearningResult> getWordInfo(String word, String context) async {
    final cachedExplanation = await getCachedWord(word, context);
    final cachedPronunciation = await getCachedPronunciation(word);
    final audioPath = await _audioFileStore.resolveWordAudioPath(
      word,
      preferredPath: cachedPronunciation?.audioUrl,
    );

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

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(
    String word,
    List<int> bytes,
    AudioFormat format,
  ) {
    return _audioFileStore.saveWordAudioFile(word, bytes, format);
  }

  Future<void> persistAudioPath(String word, String audioPath) {
    return _cacheStore.savePronunciationPath(word, audioPath);
  }

  /// 流式获取单词解释并自动持久化
  Stream<String> getWordExplanationStream(String word, String context) async* {
    String fullContent = '';

    // 同时启动 AI 查询
    final aiStream = _deepSeekService.explainWordStream(word, context);

    await for (final chunk in aiStream) {
      fullContent += chunk;
      yield chunk;
    }

    // 当 AI 解释完成时，保存到 Isar 缓存
    if (fullContent.isNotEmpty) {
      await _cacheStore.saveExplanation(
        word: word,
        context: context,
        explanation: fullContent,
      );
    }
  }
}
