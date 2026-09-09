/// 应用语义化版本：major.minor.patch + 构建号。
///
/// split APK（arm64、armeabi-v7a、x86_64）的构建号带架构偏移
///（如构建 1 实际为 1001 / 1002 / 1003），比较前按 1000 取余归一化。
class AppVersion {
  const AppVersion(this.major, this.minor, this.patch, {this.build = 0});

  final int major;
  final int minor;
  final int patch;
  final int build;

  /// 从 `1.2.3` 形式的版本串与平台构建号构造；构建号自动归一化。
  factory AppVersion.parse(String version, {int buildNumber = 0}) {
    final parts = version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    return AppVersion(
      parts.isNotEmpty ? parts[0] : 0,
      parts.length > 1 ? parts[1] : 0,
      parts.length > 2 ? parts[2] : 0,
      build: buildNumber % 1000,
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
