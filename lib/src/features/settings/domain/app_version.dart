/// 应用语义化版本：major.minor.patch + 构建号。
///
/// 构建号取原值，不做归一化：本仓库只出 arm64 单 ABI 包，split 构建才带的
/// `abiCode * 1000` 前缀偏移不会出现；取余归一化反而会截断四位数构建号
/// （`MAJOR*10000+MINOR*100+PATCH` 从 v1.0.0 起就是五位数），使版本比较失真。
class AppVersion {
  const AppVersion(this.major, this.minor, this.patch, {this.build = 0});

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// 从 `1.2.3` 形式的版本串与平台构建号构造。
  factory AppVersion.parse(String version, {int buildNumber = 0}) {
    final parts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    return AppVersion(
      parts.isNotEmpty ? parts[0] : 0,
      parts.length > 1 ? parts[1] : 0,
      parts.length > 2 ? parts[2] : 0,
      build: buildNumber,
    );
  }

  /// 逐段比较：major → minor → patch → 构建号。
  bool isNewerThan(AppVersion other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    if (patch != other.patch) return patch > other.patch;
    return build > other.build;
  }

  @override
  String toString() => '$major.$minor.$patch+$build';
}
