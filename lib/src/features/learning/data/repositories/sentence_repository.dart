import 'dart:io';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lumina/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:lumina/src/features/learning/data/services/deep_seek_service.dart';
import '../../domain/sentence_analysis.dart';

/// 句子学习结果
class SentenceLearningResult {
  /// 句子语法和成分分析 (Markdown 格式)
  final String? analysis;

  /// 句子朗读音频文件路径 (来自 TTS)
  final String? audioUrl;

  /// 是否是缓存结果
  final bool isFromCache;

  SentenceLearningResult({
    this.analysis,
    this.audioUrl,
    this.isFromCache = false,
  });
}

/// 句子学习仓库，专门负责句子的语法分析、TTS 朗读及缓存逻辑
class SentenceRepository {
  final DeepSeekService _deepSeekService;
  final AliyunTTSService _aliyunTTSService;
  final Isar _isar;

  SentenceRepository(
    this._deepSeekService,
    this._aliyunTTSService,
    this._isar,
  );

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
    // 1. 优先检查缓存
    final cached = await getCachedSentence(sentence);
    if (cached != null) {
      return SentenceLearningResult(
        analysis: cached.analysis,
        audioUrl: cached.audioUrl, // 本地文件路径
        isFromCache: true,
      );
    }

    // 2. 无缓存情况：直接返回空结果，由 UI 决定并行逻辑
    // 但在返回前，先检查本地是否已经有音频文件，如果有则直接返回路径
    final audioFile = await _getAudioFile(sentence);
    String? existingAudioPath;
    if (await audioFile.exists()) {
      existingAudioPath = audioFile.path;
    }

    return SentenceLearningResult(
      analysis: null,
      audioUrl: existingAudioPath,
      isFromCache: false,
    );
  }

  /// 获取确定性的音频文件对象
  Future<File> _getAudioFile(String sentence) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    // 使用 MD5 或简单的清理确保文件名安全且唯一
    // 这里使用 hashCode 并不完全安全（冲突概率），但在句子场景下可接受，
    // 或者使用 MD5 库。为了简单起见，这里使用 hashCode 并清理特殊字符。
    // 更好的做法是引入 crypto 包做 md5。
    // 这里暂时使用 hashCode。
    final safeHash = sentence.hashCode.toString();
    return File('${audioDir.path}/sentence_$safeHash.mp3');
  }

  /// 获取句子的发音音频字节流
  Stream<List<int>> getPronunciationStream(String sentence) {
    return _aliyunTTSService.generateAudioStream(sentence);
  }

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(String sentence, List<int> bytes) async {
    final file = await _getAudioFile(sentence);
    
    // 如果文件已存在，直接返回，不重复写入
    if (await file.exists()) {
      return file.path;
    }

    await file.writeAsBytes(bytes);
    return file.path;
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
    await for (final chunk in _deepSeekService.analyzeSentenceStream(sentence)) {
      fullContent += chunk;
      yield chunk;
    }

    // 等待音频文件保存完成
    final audioPath = await audioFilePathFuture;

    // 当 AI 分析流结束且内容有效时，保存到 Isar 缓存
    if (fullContent.isNotEmpty) {
      final newCache = SentenceAnalysis()
        ..sentence = sentence
        ..analysis = fullContent
        ..lastUpdated = DateTime.now()
        ..audioUrl = audioPath;
      
      await _isar.writeTxn(() => _isar.sentenceAnalysis.put(newCache));
    }
  }
}
