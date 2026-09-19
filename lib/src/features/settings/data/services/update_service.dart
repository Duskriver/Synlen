import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/settings/domain/app_version.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';

/// 更新清单与 APK 下载服务：拉取并解析远端 version.json、读取本地版本、
/// 下载 APK 到缓存目录并做完整性校验。
///
/// 平台依赖（HTTP、包信息、缓存目录）全部经构造注入，测试可 fake。
/// 失败一律抛 [UpdateException]，由 application 层转成状态。
class UpdateService {
  UpdateService({
    required Dio dio,
    required String versionEndpoint,
    required Future<PackageInfo> Function() readPackageInfo,
    required Future<Directory> Function() cacheDirectory,
  }) : _dio = dio,
       _versionEndpoint = versionEndpoint,
       _readPackageInfo = readPackageInfo,
       _cacheDirectory = cacheDirectory;

  final Dio _dio;
  final String _versionEndpoint;
  final Future<PackageInfo> Function() _readPackageInfo;
  final Future<Directory> Function() _cacheDirectory;

  /// 拉取并解析远端版本清单。
  Future<VersionManifest> fetchManifest() async {
    try {
      final response = await _dio.get<String>(
        _versionEndpoint,
        options: Options(responseType: ResponseType.plain),
      );
      final jsonMap = jsonDecode(response.data ?? '') as Map<String, dynamic>;
      if (jsonMap['code'] != 200) {
        throw UpdateException(
          UpdateErrorCode.checkFailed,
          '服务端返回 code ${jsonMap['code']}',
        );
      }
      return _parseManifest(jsonMap['data'] as Map<String, dynamic>);
    } on UpdateException {
      rethrow;
    } catch (e) {
      throw UpdateException(UpdateErrorCode.checkFailed, e);
    }
  }

  /// 本地版本（构建号已按 split APK 约定归一化）。
  Future<AppVersion> localVersion() async {
    final info = await _readPackageInfo();
    return AppVersion.parse(
      info.version,
      buildNumber: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  /// 安装包在缓存目录内的相对路径：`apk/synlen-<版本>.apk`。
  ///
  /// 这是落点的唯一声明：下载按它写文件，application 把它交给 presentation 拼
  /// content URI，Android 侧 `file_paths.xml` 的 `apk_cache` 映射覆盖同一棵缓存
  /// 目录。三者必须对齐，`test/features/settings/update_install_uri_test.dart`
  /// 把这条契约钉住。
  static String apkRelativePath(String versionLabel) =>
      'apk/synlen-$versionLabel.apk';

  /// 下载 [manifest] 的 APK 到缓存目录并校验完整性，返回安装包路径。
  ///
  /// 直链由远端 version.json 下发，只允许 HTTPS，防止被降级为明文篡改；
  /// 清单提供 androidApkSha256 时比对摘要，不匹配即删除文件并中止。
  Future<String> downloadApk({
    required VersionManifest manifest,
    void Function(double progress)? onProgress,
  }) async {
    final url = manifest.androidApkUrl;
    if (url.isEmpty) {
      throw const UpdateException(UpdateErrorCode.noUpdateChannel);
    }
    if (Uri.tryParse(url)?.scheme != 'https') {
      appLogger.w('拦截非 HTTPS 更新直链: $url');
      throw const UpdateException(UpdateErrorCode.insecureUrl);
    }

    final cacheDir = await _cacheDirectory();
    final apkPath =
        '${cacheDir.path}/${apkRelativePath(manifest.versionLabel)}';
    await File(apkPath).parent.create(recursive: true);
    // 删除可能存在的旧文件，避免覆盖安装校验失败
    final oldFile = File(apkPath);
    if (oldFile.existsSync()) {
      oldFile.deleteSync();
    }

    try {
      await _dio.download(
        url,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );
    } catch (e) {
      throw UpdateException(UpdateErrorCode.downloadFailed, e);
    }

    await _verifyChecksum(apkPath, manifest.androidApkSha256);
    return apkPath;
  }

  VersionManifest _parseManifest(Map<String, dynamic> data) {
    return VersionManifest(
      major: (data['majorNumber'] as num).toInt(),
      minor: (data['minorNumber'] as num).toInt(),
      patch: (data['patchNumber'] as num).toInt(),
      build: (data['buildNumber'] as num).toInt(),
      updateLog: data['updateLog'] as String? ?? '',
      lanzouUrl: data['lanzouUrl'] as String? ?? '',
      lanzouPassword: data['lanzouPassword'] as String? ?? '',
      githubUrl: data['githubUrl'] as String? ?? '',
      androidApkUrl: data['androidApkUrl'] as String? ?? '',
      androidApkSha256: data['androidApkSha256'] as String? ?? '',
      iosAppStoreUrl: data['iosAppStoreUrl'] as String? ?? '',
    );
  }

  /// 清单提供 [expectedSha256] 时校验下载文件摘要；
  /// 字段缺失时放行（兼容旧的已发布清单），仅记 warning。校验失败删除文件。
  Future<void> _verifyChecksum(String apkPath, String expectedSha256) async {
    final expected = expectedSha256.trim().toLowerCase();
    if (expected.isEmpty) {
      appLogger.w('version.json 未提供 androidApkSha256，跳过完整性校验');
      return;
    }
    final actual = (await sha256.bind(File(apkPath).openRead()).first)
        .toString();
    if (actual == expected) return;
    appLogger.w('APK 摘要不匹配: 期望 $expected，实际 $actual');
    final file = File(apkPath);
    if (file.existsSync()) file.deleteSync();
    throw UpdateException(
      UpdateErrorCode.checksumMismatch,
      '期望 $expected，实际 $actual',
    );
  }
}
