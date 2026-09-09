import 'app_version.dart';

/// 远端 version.json 下发的版本清单（值类型；JSON 解析在 data 层）。
class VersionManifest {
  const VersionManifest({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
    this.updateLog = '',
    this.lanzouUrl = '',
    this.lanzouPassword = '',
    this.githubUrl = '',
    this.androidApkUrl = '',
    this.androidApkSha256 = '',
    this.iosAppStoreUrl = '',
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// 更新日志（Markdown 片段）
  final String updateLog;

  /// 蓝奏云兜底下载地址与提取码
  final String lanzouUrl;
  final String lanzouPassword;

  /// GitHub Releases 地址
  final String githubUrl;

  /// Android：APK 直链（国内 OSS 分发）
  final String androidApkUrl;

  /// Android：清单下发的 APK SHA-256（十六进制）；为空跳过校验（兼容旧清单）
  final String androidApkSha256;

  /// iOS：App Store 链接（上架后由服务端下发）
  final String iosAppStoreUrl;

  /// 清单版本，用于与本地版本比较
  AppVersion get version => AppVersion(major, minor, patch, build: build);

  /// 展示用版本标签，如 `v1.2.3+4`
  String get versionLabel => 'v$major.$minor.$patch+$build';
}
