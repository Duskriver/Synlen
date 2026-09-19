import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/presentation/update_install_uri.dart';

/// 安装 URI 的 Android 侧契约：authority、`file_paths.xml` 映射与下载落点必须
/// 对齐。三处分别在 Dart 常量、`AndroidManifest.xml` 与 `file_paths.xml` 里，
/// 谁也看不见谁——v0.3.0 至 v0.3.4 的安装失败就是它们脱节造成的：APK 被放进
/// 缓存 `apk/` 子目录，交给安装器的 URI 却只带文件名，FileProvider 到缓存根
/// 找文件，系统报 `open failed: ENOENT`。
void main() {
  final manifestXml = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final filePathsXml = File(
    'android/app/src/main/res/xml/file_paths.xml',
  ).readAsStringSync();

  test('FileProvider 的 authority 后缀与 Dart 常量一致', () {
    expect(
      manifestXml,
      contains(
        'android:authorities="\${applicationId}.$apkFileProviderAuthoritySuffix"',
      ),
      reason: 'AndroidManifest.xml 的 authority 必须与 apkFileProviderAuthoritySuffix 同步',
    );
  });

  test('FileProvider 用 file_paths.xml 且声明了映射名', () {
    expect(
      manifestXml,
      contains('android:resource="@xml/file_paths"'),
      reason: 'FileProvider 的路径配置必须指向 file_paths.xml',
    );
    expect(
      filePathsXml,
      contains('name="$apkFileProviderPathName"'),
      reason: 'file_paths.xml 必须提供 apkFileProviderPathName 这个名字的映射',
    );
  });

  test('URI 经 FileProvider 映射后落回下载落点', () {
    final mapped = RegExp(
      '<cache-path\\s+name="$apkFileProviderPathName"\\s+path="([^"]*)"',
    ).firstMatch(filePathsXml)?.group(1);
    expect(
      mapped,
      isNotNull,
      reason: 'apk_cache 必须声明为 cache-path（缓存目录），否则映射根就不是下载目录',
    );

    const versionLabel = '9.9.9';
    final relativePath = UpdateService.apkRelativePath(versionLabel);
    final uri = Uri.parse(
      apkContentUri(
        packageName: 'com.example.synlen',
        apkRelativePath: relativePath,
      ),
    );

    // content URI 的路径形如 /apk_cache/apk/synlen-9.9.9.apk：首段是映射名，
    // 其余是相对映射根的路径。
    expect(uri.pathSegments.first, apkFileProviderPathName);
    final throughMapping = uri.pathSegments.skip(1).join('/');
    expect(
      p.normalize(p.join(mapped!, throughMapping)),
      p.normalize(relativePath),
      reason:
          'FileProvider 解析出的路径必须等于下载落点（缓存根/$relativePath）；'
          '只带文件名就会退回缓存根，安装器报 ENOENT',
    );
  });
}
