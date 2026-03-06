import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lumina/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:lumina/src/features/learning/data/services/deep_seek_service.dart';
import 'package:lumina/src/features/learning/data/services/free_dictionary_service.dart';
import '../../domain/word_explanation.dart';

/// 单词学习结果
class WordLearningResult {
  /// 发音音频 URL (来自 API 或 TTS)
  final String? audioUrl;

  /// 单词解释 (Markdown 格式)
  final String? explanation;

  /// 是否是缓存结果
  final bool isFromCache;

  WordLearningResult({
    this.audioUrl,
    this.explanation,
    this.isFromCache = false,
  });
}

/// 单词学习仓库，专门负责单词的发音、解释及缓存逻辑
class WordRepository {
  final FreeDictionaryService _freeDictionaryService;
  final DeepSeekService _deepSeekService;
  final AliyunTTSService _aliyunTTSService;
  final Isar _isar;

  WordRepository(
    this._freeDictionaryService,
    this._deepSeekService,
    this._aliyunTTSService,
    this._isar,
  );

  /// 从本地缓存获取单词信息
  Future<WordExplanation?> getCachedWord(String word, String context) async {
    // 使用确定的 Hash ID 直接查找，实现 O(1) 精确匹配
    final id = WordExplanation.generateId(word, context);
    return await _isar.wordExplanations.get(id);
  }

  /// 获取单词的发音音频字节流
  ///
  /// 业务逻辑：
  /// 1. 首先尝试从免费词典 API 获取 URL
  /// 2. 如果成功，流式下载该 URL 的内容
  /// 3. 如果失败，调用阿里云 TTS 流式接口
  Stream<List<int>> getPronunciationStream(String word) async* {
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
          await for (final chunk in response.data!.stream) {
            yield chunk as List<int>;
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Free Dictionary Audio error, falling back to Aliyun TTS: $e');
    }

    // 2. 降级到阿里云 TTS 流式
    yield* _aliyunTTSService.generateAudioStream(word);
  }

  /// 获取单词基础信息
  ///
  /// [word] 目标单词
  /// [context] 上下文句子
  /// 返回 [WordLearningResult]，如果 explanation 为 null 且 isFromCache 为 false，
  /// UI 应并行启动 getWordExplanationStream 和 getPronunciationStream
  Future<WordLearningResult> getWordInfo(String word, String context) async {
    // 1. 优先检查缓存
    final cached = await getCachedWord(word, context);
    if (cached != null) {
      return WordLearningResult(
        audioUrl: cached.audioUrl, // 这里存的是本地文件路径
        explanation: cached.explanation,
        isFromCache: true,
      );
    }

    // 2. 无缓存，直接返回空结果，由 UI 决定并行逻辑
    // 但在返回前，先检查本地是否已经有音频文件，如果有则直接返回路径
    final audioFile = await _getAudioFile(word);
    String? existingAudioPath;
    if (await audioFile.exists()) {
      existingAudioPath = audioFile.path;
    }

    return WordLearningResult(
      audioUrl: existingAudioPath,
      explanation: null,
      isFromCache: false,
    );
  }

  /// 获取确定性的音频文件对象
  Future<File> _getAudioFile(String word) async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDir.path}/audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    // 使用 MD5 或简单的清理确保文件名安全且唯一
    // 这里简单地移除非字母数字字符，实际生产环境建议使用 hash
    final safeWord = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return File('${audioDir.path}/word_$safeWord.mp3');
  }

  /// 保存音频文件到本地并返回路径
  Future<String> saveAudioFile(String word, List<int> bytes) async {
    final file = await _getAudioFile(word);

    // 如果文件已存在，直接返回，不重复写入
    if (await file.exists()) {
      return file.path;
    }

    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 流式获取单词解释并自动持久化
  Stream<String> getWordExplanationStream(
    String word,
    String context, {
    required Future<String?> audioFilePathFuture,
  }) async* {
    String fullContent = '';

    // 同时启动 AI 查询
    final aiStream = _deepSeekService.explainWordStream(word, context);

    await for (final chunk in aiStream) {
      fullContent += chunk;
      yield chunk;
    }

    // AI 流结束后，等待音频文件保存完成
    final audioPath = await audioFilePathFuture;

    // 当 AI 解释完成时，保存到 Isar 缓存
    if (fullContent.isNotEmpty) {
      final newCache = WordExplanation()
        ..id =
            WordExplanation.generateId(word, context) // 显式设置基于内容的 ID
        ..word = word
        ..explanation = fullContent
        ..lastUpdated = DateTime.now()
        ..context = context
        ..audioUrl = audioPath; // 保存本地文件路径

      await _isar.writeTxn(() => _isar.wordExplanations.put(newCache));
    }
  }
}
