class AppInfo {
  const AppInfo._();

  static const appName = 'Synlen';
  static const appAuthor = 'TangLei';

  static const originalProjectName = 'Lumina';
  static const originalAuthor = 'MilkFeng';
  static const originalRepositoryUrl = 'https://github.com/MilkFeng/lumina';

  static const projectRepositoryUrl = 'https://github.com/Duskriver/Synlen';

  /// 版本检查端点：Gitee 分发仓库中的 version.json。
  /// 可通过 --dart-define=SYNLEN_VERSION_URL=xxx 覆盖（如自建分发源）。
  static const versionEndpoint = String.fromEnvironment(
    'SYNLEN_VERSION_URL',
    defaultValue:
        'https://gitee.com/Tang_Lei789/synlen/raw/updates/version.json',
  );

  static const applicationLegalese =
      'Synlen is based on Lumina by MilkFeng. Original project licensed under MIT.';
  static const bundledLicenseAsset = 'assets/licenses/lumina_mit.txt';

  /// flutter_sound 以 MPL-2.0 发布，其许可文本需随应用分发。
  static const flutterSoundLicenseAsset =
      'assets/licenses/flutter_sound_mpl2.txt';
}
