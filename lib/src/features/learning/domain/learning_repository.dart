import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';

/// 学习信息查询结果：文本内容与音频路径及其缓存状态。
class LearningInfo {
  /// 单词释义为四条 NDJSON，句子分析为 Markdown；未命中缓存时为 null。
  final String? content;

  /// 发音音频 URL 或本地路径；未命中缓存时为 null。
  final String? audioUrl;

  /// 文本内容是否来自缓存
  final bool hasCachedContent;

  /// 音频是否已缓存
  final bool hasCachedAudio;

  const LearningInfo({
    this.content,
    this.audioUrl,
    this.hasCachedContent = false,
    this.hasCachedAudio = false,
  });

  bool get isFullyCached => hasCachedContent && hasCachedAudio;
}

/// 词/句学习仓库的抽象：查询缓存信息、正文流、发音流与音频持久化。
///
/// 词与句的实现差异（免费词典降级、按音色缓存策略）留在各自实现里。
abstract interface class LearningRepository {
  /// 查询文本与音频缓存信息。
  ///
  /// 返回的 [LearningInfo] 若文本未命中缓存，调用方应启动 [getContentStream]。
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  });

  /// 单词逐条输出已验证的完整 NDJSON 记录，句子输出 Markdown 片段。
  /// 只有正文与传输均完整成功才落缓存。
  Stream<String> getContentStream(
    LearningQuery query, {
    LearningCancellation? cancellation,
  });

  /// 发音音频字节流结果（包含流与格式）。
  Stream<AudioStreamResult> getPronunciationStream(
    String target, {
    LearningCancellation? cancellation,
  });

  /// 保存音频文件到本地并返回路径；保存后按容量预算清退最旧音频。
  Future<String> saveAudioFile(
    String target,
    List<int> bytes,
    AudioFormat format, {
    required bool cacheByVoice,
  });

  /// 把解析出的音频路径回写进发音缓存。
  Future<void> persistAudioPath(String target, String audioPath);
}
