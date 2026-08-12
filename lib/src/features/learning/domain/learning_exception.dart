/// 学习模块领域错误码：展示层据此映射为本地化文案（规范 §5：用户文案与内部细节分离）。
enum LearningErrorCode {
  /// 未配置 DeepSeek API Key
  noDeepSeekApiKey,

  /// 未配置阿里云 TTS API Key
  noAliyunTtsApiKey,

  /// AI 服务暂时不可用
  serviceUnavailable,

  /// 服务没有返回内容
  emptyResult,

  /// 请求失败（网络/解析等），细节见 [LearningException.details]
  requestFailed,

  /// 音频文件不存在
  audioFileMissing,

  /// 不支持的音频格式
  unsupportedFormat,

  /// 没有可播放的音频
  noPlayableAudio,
}

/// 学习模块领域异常。
///
/// [details] 为内部细节，仅用于日志，**不上屏**。
class LearningException implements Exception {
  final LearningErrorCode code;
  final Object? details;

  const LearningException(this.code, [this.details]);

  @override
  String toString() => details == null
      ? 'LearningException(${code.name})'
      : 'LearningException(${code.name}: $details)';
}
