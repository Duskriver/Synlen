import 'dart:convert';

import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';
import 'package:synlen/src/features/learning/domain/word_definition_parser.dart';

/// 单词学习仓库，专门负责单词的发音、解释及缓存逻辑
class WordRepository implements LearningRepository {
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

  /// 优先获取完整词典 MP3，失败时回退阿里云 PCM 流。
  @override
  Stream<AudioStreamResult> getPronunciationStream(
    String word, {
    LearningCancellation? cancellation,
  }) async* {
    try {
      cancellation?.throwIfCancelled();
      final dictionaryAudio = await _freeDictionaryService
          .getPronunciationAudio(word, cancellation: cancellation);
      cancellation?.throwIfCancelled();
      if (dictionaryAudio != null && dictionaryAudio.isNotEmpty) {
        yield AudioStreamResult(
          stream: Stream.value(dictionaryAudio),
          format: AudioFormat.mp3,
          cacheByVoice: false,
        );
        return;
      }
    } catch (e) {
      cancellation?.throwIfCancelled();
      appLogger.w(
        'Free Dictionary Audio error, falling back to Aliyun TTS: $e',
      );
    }

    cancellation?.throwIfCancelled();
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
  /// 返回 [LearningInfo]，如果 content 为 null 且 hasCachedContent 为 false，
  /// UI 应并行启动 getContentStream 和 getPronunciationStream
  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async {
    final wordQuery = query as WordLearningQuery;
    final word = wordQuery.word;
    final context = wordQuery.context;
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

    return LearningInfo(
      audioUrl: audioPath,
      content: cachedExplanation?.explanation,
      hasCachedContent: cachedExplanation?.explanation.isNotEmpty ?? false,
      hasCachedAudio: audioPath != null,
    );
  }

  /// 保存音频文件到本地并返回路径；保存后按容量预算清退最旧音频。
  @override
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

  @override
  Future<void> persistAudioPath(String word, String audioPath) {
    return _cacheStore.savePronunciationPath(word, audioPath);
  }

  /// 逐条发出已验证的记录，四条齐全且上游正常完成后才写入缓存。
  @override
  Stream<String> getContentStream(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async* {
    final wordQuery = query as WordLearningQuery;
    final word = wordQuery.word;
    final context = wordQuery.context;
    cancellation?.throwIfCancelled();
    final fullContent = StringBuffer();
    final parser = WordDefinitionParser();

    final aiStream = _deepSeekService.explainWordStream(
      word,
      context,
      cancellation: cancellation,
    );

    await for (final line in aiStream.transform(const LineSplitter())) {
      cancellation?.throwIfCancelled();
      if (line.trim().isEmpty) continue;
      parser.addLine(line);
      final record = '$line\n';
      fullContent.write(record);
      yield record;
    }

    cancellation?.throwIfCancelled();
    parser.finish();
    await _cacheStore.saveExplanation(
      word: word,
      context: context,
      explanation: fullContent.toString(),
    );
  }
}
