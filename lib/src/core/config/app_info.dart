class AppInfo {
  const AppInfo._();

  static const appName = 'Synlen';
  static const appAuthor = 'TangLei';

  static const originalProjectName = 'Lumina';
  static const originalAuthor = 'MilkFeng';
  static const originalRepositoryUrl = 'https://github.com/MilkFeng/lumina';

  static const projectRepositoryUrl = 'https://github.com/Duskriver/Synlen';

  /// 版本检查端点：阿里云 OSS 上的 version.json（国内网络可达）。
  /// 可通过 --dart-define=SYNLEN_VERSION_URL=xxx 覆盖（如自建分发源）。
  static const versionEndpoint = String.fromEnvironment(
    'SYNLEN_VERSION_URL',
    defaultValue: 'https://synlen.oss-cn-hangzhou.aliyuncs.com/version.json',
  );

  static const applicationLegalese =
      'Synlen is based on Lumina by MilkFeng. Original project licensed under MIT.';
  static const bundledLicenseAsset = 'assets/licenses/lumina_mit.txt';
}
