import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lumina/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:lumina/src/features/learning/data/services/deep_seek_service.dart';
import '../../domain/sentence_analysis.dart';

import 'package:lumina/src/features/learning/domain/audio_stream_result.dart';

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
  final Isar _isar;

  SentenceRepository(this._deepSeekService, this._aliyunTTSService, this._isar);

  /// 从本地缓存获取句子分析信息
  Future<SentenceAnalysis?> getCachedSentence(String sentence) async {
    return await _isar.sentenceAnalysis
        .where()
        .sentenceEqualTo(sentence)
        .findFirst();
  }

  /// 获取句子基础信息
  ///
  /// [sentence] 目标句子
  /// 返回 [SentenceLearningResult]，如果 analysis 为 null 且 isFromCache 为 false，
  /// UI 应并行启动 getSentenceAnalysisStream 和 getPronunciationStream
  Future<SentenceLearningResult> getSentenceInfo(String sentence) async {
    final cached = await getCachedSentence(sentence);
    final cachedAudioPath = await _resolveAudioPath(sentence, cached?.audioUrl);

    return SentenceLearningResult(
      analysis: cached?.analysis,
      audioUrl: cachedAudioPath,
      hasCachedAnalysis: cached?.analysis.isNotEmpty ?? false,
      hasCachedAudio: cachedAudioPath != null,
    );
  }

  /// 查找本地已有的音频文件
  Future<File?> _findExistingAudioFile(String sentence) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) return null;

    final candidateKeys = <String>[
      _stableSentenceHash(sentence),
      sentence.hashCode.toString(),
    ];

    for (final key in candidateKeys) {
      final wavFile = File('${audioDir.path}/sentence_$key.wav');
      if (await wavFile.exists()) return wavFile;

      final mp3File = File('${audioDir.path}/sentence_$key.mp3');
      if (await mp3File.exists()) return mp3File;
    }

    return null;
  }

  /// 获取确定性的音频文件对象
  Future<File> _getAudioFile(String sentence) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final safeHash = _stableSentenceHash(sentence);
    // 句子固定使用 .wav 因为来自阿里云 PCM
    return File('${audioDir.path}/sentence_$safeHash.wav');
  }

  /// 获取句子的发音音频字节流结果 (PCM)
  Stream<AudioStreamResult> getPronunciationStream(String sentence) async* {
    yield AudioStreamResult(
      stream: _aliyunTTSService.generateAudioStream(sentence),
      format: AudioFormat.pcm,
    );
  }

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(String sentence, List<int> bytes) async {
    // 检查是否已经存在
    final existing = await _findExistingAudioFile(sentence);
    if (existing != null) return existing.path;

    final file = await _getAudioFile(sentence);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> persistAudioPath(String sentence, String audioPath) async {
    final cached = await getCachedSentence(sentence);
    if (cached == null) {
      return;
    }

    cached.audioUrl = audioPath;
    cached.lastUpdated = DateTime.now();
    await _isar.writeTxn(() => _isar.sentenceAnalysis.put(cached));
  }

  /// 流式获取句子分析并自动持久化
  ///
  /// [audioFilePathFuture] 预先获取的音频文件路径的 Future
  Stream<String> getSentenceAnalysisStream(
    String sentence, {
    required Future<String?> audioFilePathFuture,
  }) async* {
    String fullContent = '';

    // 调用 DeepSeek AI 进行句子分析
    await for (final chunk in _deepSeekService.analyzeSentenceStream(
      sentence,
    )) {
      fullContent += chunk;
      yield chunk;
    }

    // 等待音频文件保存完成
    final audioPath = await audioFilePathFuture;

    // 当 AI 分析流结束且内容有效时，保存到 Isar 缓存
    if (fullContent.isNotEmpty) {
      final cached = await getCachedSentence(sentence);
      final entry = cached ?? SentenceAnalysis()
        ..sentence = sentence;
      entry.analysis = fullContent;
      entry.lastUpdated = DateTime.now();
      entry.audioUrl = audioPath ?? entry.audioUrl;

      await _isar.writeTxn(() => _isar.sentenceAnalysis.put(entry));
    }
  }

  Future<String?> _resolveAudioPath(
    String sentence,
    String? preferredPath,
  ) async {
    if (preferredPath != null && preferredPath.isNotEmpty) {
      final preferredFile = File(preferredPath);
      if (await preferredFile.exists()) {
        return preferredFile.path;
      }
    }

    final existingFile = await _findExistingAudioFile(sentence);
    return existingFile?.path;
  }
}

String _stableSentenceHash(String sentence) {
  var hash = 0xcbf29ce484222325;

  for (var i = 0; i < sentence.length; i++) {
    final codeUnit = sentence.codeUnitAt(i);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash.toUnsigned(64).toRadixString(16);
}
