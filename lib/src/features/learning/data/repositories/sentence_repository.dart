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
    return SentenceLearningResult(
      analysis: null,
      audioUrl: null,
      isFromCache: false,
    );
  }

  /// 获取句子的发音音频字节流
  Stream<List<int>> getPronunciationStream(String sentence) {
    return _aliyunTTSService.generateAudioStream(sentence);
  }

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(String sentence, List<int> bytes) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    
    final fileName = 'sentence_${sentence.hashCode}_${DateTime.now().millisecondsSinceEpoch}.mp3';
    final file = File('${audioDir.path}/$fileName');
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
