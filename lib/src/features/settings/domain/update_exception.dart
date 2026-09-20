/// 更新模块领域错误码：展示层据此映射为本地化文案（规范 §5：用户文案与内部细节分离）。
enum UpdateErrorCode {
  /// 检查更新失败（网络、超时或清单解析错误），细节见 [UpdateException.details]
  checkFailed,

  /// 当前平台没有可用的下载渠道（清单未下发直链）
  noUpdateChannel,

  /// 下载直链非 HTTPS，已拒绝
  insecureUrl,

  /// 更新包下载失败
  downloadFailed,

  /// 更新包 SHA-256 校验不匹配
  checksumMismatch,

  /// 清单未提供有效的 APK SHA-256。
  invalidChecksum,

  /// 系统安装器无法启动或安装请求失败。
  installFailed,

  /// 系统未授予安装所需权限。
  installPermissionDenied,
}

/// 更新模块领域异常。
///
/// [details] 为内部细节，仅用于日志，**不上屏**。
class UpdateException implements Exception {
  final UpdateErrorCode code;
  final Object? details;

  const UpdateException(this.code, [this.details]);

  @override
  String toString() => details == null
      ? 'UpdateException(${code.name})'
      : 'UpdateException(${code.name}: $details)';
}
