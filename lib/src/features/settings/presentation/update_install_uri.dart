/// 交给系统安装器的 content URI 拼装。
///
/// 这三个值与 Android 侧配置成对存在，改动必须两边同步：
/// - [apkFileProviderAuthoritySuffix] ↔ `AndroidManifest.xml` 里
///   `${applicationId}.fileprovider` 这个 FileProvider；
/// - [apkFileProviderPathName] ↔ `android/app/src/main/res/xml/file_paths.xml`
///   声明为 `cache-path` 的映射名（映射整棵缓存目录）；
/// - [apkRelativePath] 由 data 层的 `UpdateService.apkRelativePath` 声明，是
///   下载落点相对缓存目录的位置。
///
/// 三者任一处脱节，FileProvider 就会解析到别的路径，安装器报
/// `open failed: ENOENT`——v0.3.0 至 v0.3.4 的安装失败正是这么来的（把 APK 放进
/// `apk/` 子目录后，URI 仍只带文件名）。契约由
/// `test/features/settings/update_install_uri_test.dart` 钉住。
library;

/// FileProvider authority 的后缀，前面接应用包名。
const apkFileProviderAuthoritySuffix = 'fileprovider';

/// `file_paths.xml` 里暴露缓存目录的映射名。
const apkFileProviderPathName = 'apk_cache';

/// 拼出指向缓存内安装包的 content URI。
///
/// [apkRelativePath] 取自 `UpdateDownloadState.apkRelativePath`，即
/// `UpdateService.apkRelativePath` 的返回值。
String apkContentUri({
  required String packageName,
  required String apkRelativePath,
}) {
  return 'content://$packageName.$apkFileProviderAuthoritySuffix/'
      '$apkFileProviderPathName/$apkRelativePath';
}
