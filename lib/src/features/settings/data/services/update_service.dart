import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/features/settings/domain/app_version.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';

/// 更新清单与安装服务；原生事件由 application 转成状态与错误码。
class UpdateService {
  UpdateService({
    required Dio dio,
    required String versionEndpoint,
    required Future<PackageInfo> Function() readPackageInfo,
    required OtaUpdate Function() createUpdater,
    required Future<Directory> Function() supportDirectory,
  }) : _dio = dio,
       _versionEndpoint = versionEndpoint,
       _readPackageInfo = readPackageInfo,
       _createUpdater = createUpdater,
       _supportDirectory = supportDirectory;

  final Dio _dio;
  final String _versionEndpoint;
  final Future<PackageInfo> Function() _readPackageInfo;
  final OtaUpdate Function() _createUpdater;
  final Future<Directory> Function() _supportDirectory;
  OtaUpdate? _updater;
  bool _canceled = false;

  // 固定文件名使插件重试时覆盖同一文件，避免各版本 APK 在私有目录累积。
  static const apkFilename = 'synlen-update.apk';

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

  /// 本地版本，构建号按原值比较。
  Future<AppVersion> localVersion() async {
    final info = await _readPackageInfo();
    return AppVersion.parse(
      info.version,
      buildNumber: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  /// 下载、校验并拉起系统安装器。调用方必须串行执行，并在退出时取消下载。
  Stream<OtaEvent> downloadAndInstall(VersionManifest manifest) {
    final url = manifest.androidApkUrl;
    if (url.isEmpty) {
      throw const UpdateException(UpdateErrorCode.noUpdateChannel);
    }
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const UpdateException(UpdateErrorCode.insecureUrl);
    }
    final checksum = manifest.androidApkSha256.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum)) {
      throw const UpdateException(UpdateErrorCode.invalidChecksum);
    }
    _canceled = false;
    _updater = null;
    return _startDownload(manifest, checksum);
  }

  Stream<OtaEvent> _startDownload(
    VersionManifest manifest,
    String checksum,
  ) async* {
    final directory = await _updateDirectory();
    await directory.create(recursive: true);
    final record = File('${directory.path}/pending.json');
    final temporary = File('${record.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'major': manifest.major,
        'minor': manifest.minor,
        'patch': manifest.patch,
        'build': manifest.build,
        'sha256': checksum,
      }),
      flush: true,
    );
    await temporary.rename(record.path);
    // 记录必须先于原生安装落盘；准备期间取消不得在异步写入后启动插件。
    if (_canceled) return;
    // ota_update 会缓存 execute 的流；复用实例会让重试读到已关闭的旧流。
    final updater = _createUpdater();
    _updater = updater;
    yield* updater.execute(
      manifest.androidApkUrl,
      destinationFilename: apkFilename,
      sha256checksum: checksum,
    );
  }

  /// 等待原生写入和校验停止；已打开的系统安装器不在取消范围内。
  Future<void> cancelDownload() async {
    _canceled = true;
    await _updater?.cancel();
  }

  /// 仅在校验失败或启动回收确认可删后调用；先删 APK，再移除回收记录。
  Future<void> deleteDownloadedApk() async {
    final directory = await _updateDirectory();
    final file = File('${directory.path}/$apkFilename');
    if (await file.exists()) await file.delete();
    final record = File('${directory.path}/pending.json');
    if (await record.exists()) await record.delete();
  }

  /// 仅在 Android 启动、更新入口开放前调用；不能与下载或安装交接并发。
  /// 无记录的文件保守保留，完整待安装包在本地版本达到目标后才回收。
  Future<void> cleanupDownloadedApk() async {
    final directory = await _updateDirectory();
    final temporary = File('${directory.path}/pending.json.tmp');
    if (await temporary.exists()) await temporary.delete();
    final record = File('${directory.path}/pending.json');
    if (!await record.exists()) return;
    final data =
        jsonDecode(await record.readAsString()) as Map<String, dynamic>;
    final parts = ['major', 'minor', 'patch', 'build'].map((key) => data[key]);
    if (parts.any((part) => part is! int || part < 0) ||
        data['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(data['sha256'] as String)) {
      throw const FormatException('安装包回收记录无效');
    }
    final target = AppVersion(
      data['major'] as int,
      data['minor'] as int,
      data['patch'] as int,
      build: data['build'] as int,
    );
    final file = File('${directory.path}/$apkFilename');
    if (!await file.exists() || !target.isNewerThan(await localVersion())) {
      await deleteDownloadedApk();
      return;
    }
    final digest = await sha256.bind(file.openRead()).first;
    if (digest.toString() != data['sha256']) await deleteDownloadedApk();
  }

  Future<Directory> _updateDirectory() async =>
      Directory('${(await _supportDirectory()).path}/ota_update');

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
}
