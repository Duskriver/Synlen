import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/features/settings/application/update_check.dart';
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';

/// 更新检查用例：清单比较、错误码映射与下载 / 校验路径。
/// HTTP 与下载经注入的 Dio adapter fake，缓存目录用临时目录。
void main() {
  late Directory cacheDir;

  /// 默认本地版本：1.1.0+10。
  final defaultLocal = PackageInfo(
    appName: 'Synlen',
    packageName: 'com.synlen.app',
    version: '1.1.0',
    buildNumber: '10',
  );

  setUp(() async {
    cacheDir = await Directory.systemTemp.createTemp('update_check_test');
  });

  tearDown(() async {
    if (cacheDir.existsSync()) await cacheDir.delete(recursive: true);
  });

  PackageInfo localInfo(String version, String buildNumber) => PackageInfo(
    appName: 'Synlen',
    packageName: 'com.synlen.app',
    version: version,
    buildNumber: buildNumber,
  );

  ProviderContainer containerWith({
    required HttpClientAdapter adapter,
    PackageInfo? packageInfo,
  }) {
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        updateServiceProvider.overrideWithValue(
          UpdateService(
            dio: dio,
            versionEndpoint: 'https://updates.example.com/version.json',
            readPackageInfo: () async => packageInfo ?? defaultLocal,
            cacheDirectory: () async => cacheDir,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // updateCheckProvider 是 autoDispose：常驻订阅防止异步方法中途被销毁。
    final keepAlive = container.listen(updateCheckProvider, (_, _) {});
    addTearDown(keepAlive.close);
    return container;
  }

  String manifestJson({
    int major = 1,
    int minor = 1,
    int patch = 0,
    int build = 10,
    String androidApkUrl = 'https://cdn.example.com/synlen.apk',
    String? androidApkSha256,
  }) {
    final sha = androidApkSha256 == null
        ? ''
        : ',"androidApkSha256": "$androidApkSha256"';
    return '{"code": 200, "data": {'
        '"majorNumber": $major, "minorNumber": $minor, "patchNumber": $patch,'
        '"buildNumber": $build, "updateLog": "修复若干问题",'
        '"androidApkUrl": "$androidApkUrl"$sha}}';
  }

  Future<AsyncValue<UpdateState>> check(
    String manifestBody, {
    PackageInfo? packageInfo,
  }) async {
    final container = containerWith(
      adapter: _StubAdapter(manifestBody: manifestBody),
      packageInfo: packageInfo,
    );
    await container.read(updateCheckProvider.notifier).checkForUpdates();
    return container.read(updateCheckProvider);
  }

  group('checkForUpdates', () {
    test('远端版本更高 → updateAvailable，清单含 sha256 字段', () async {
      final state = await check(
        manifestJson(major: 1, minor: 2, androidApkSha256: 'ab' * 32),
      );

      final data = state.asData!.value;
      expect(data.checkStatus, UpdateCheckStatus.updateAvailable);
      expect(data.manifest?.versionLabel, 'v1.2.0+10');
      expect(data.manifest?.updateLog, '修复若干问题');
      expect(data.manifest?.androidApkSha256, 'ab' * 32);
    });

    test('远端与本地完全相同 → upToDate', () async {
      final state = await check(manifestJson());

      expect(
        state.asData!.value.checkStatus,
        UpdateCheckStatus.upToDate,
        reason: '本地 1.1.0+10，远端 1.1.0+10',
      );
    });

    test('远端语义版本更低时构建号再高也不算新版本（边界）', () async {
      final state = await check(manifestJson(minor: 0, build: 99));

      expect(
        state.asData!.value.checkStatus,
        UpdateCheckStatus.upToDate,
        reason: '远端 1.0.0+99 低于本地 1.1.0+10',
      );
    });

    test('本地构建号带 split APK 架构偏移时先归一化再比较', () async {
      // 本地构建号 1010（构建 10 的 arm64 包）与远端 10 相等 → upToDate
      final same = await check(
        manifestJson(),
        packageInfo: localInfo('1.1.0', '1010'),
      );
      expect(same.asData!.value.checkStatus, UpdateCheckStatus.upToDate);

      // 远端构建号 11 → 真有更新
      final newer = await check(
        manifestJson(build: 11),
        packageInfo: localInfo('1.1.0', '1010'),
      );
      expect(
        newer.asData!.value.checkStatus,
        UpdateCheckStatus.updateAvailable,
      );
    });

    test('网络失败 → AsyncValue error，携带 checkFailed 错误码', () async {
      final container = containerWith(
        adapter: _StubAdapter(
          manifestBody: '',
          failManifestWith: DioException.connectionError(
            requestOptions: RequestOptions(),
            reason: 'offline',
          ),
        ),
      );
      await container.read(updateCheckProvider.notifier).checkForUpdates();
      final state = container.read(updateCheckProvider);

      expect(state.hasError, isTrue);
      expect(state.error, isA<UpdateException>());
      expect(
        (state.error! as UpdateException).code,
        UpdateErrorCode.checkFailed,
      );
    });

    test('清单 code 非 200 → checkFailed', () async {
      final state = await check('{"code": 500}');

      expect(state.hasError, isTrue);
      expect(
        (state.error! as UpdateException).code,
        UpdateErrorCode.checkFailed,
      );
    });
  });

  group('downloadAndInstall', () {
    final apkBytes = Uint8List.fromList(List.generate(256, (i) => i % 251));

    Future<ProviderContainer> checkedContainerWithApk({
      required String androidApkUrl,
      String? sha256,
      HttpClientAdapter? adapter,
      bool failDownload = false,
    }) async {
      final container = containerWith(
        adapter:
            adapter ??
            _StubAdapter(
              manifestBody: manifestJson(
                minor: 2,
                androidApkUrl: androidApkUrl,
                androidApkSha256: sha256,
              ),
              apkBytes: apkBytes,
              failDownload: failDownload,
            ),
      );
      await container.read(updateCheckProvider.notifier).checkForUpdates();
      return container;
    }

    UpdateDownloadState downloadStateOf(ProviderContainer container) =>
        container.read(updateCheckProvider).asData!.value.download;

    test('非 HTTPS 直链被拒绝，不发起下载请求', () async {
      var downloadRequested = false;
      final adapter = _StubAdapter(
        manifestBody: manifestJson(
          minor: 2,
          androidApkUrl: 'http://cdn.example.com/x.apk',
        ),
        apkBytes: apkBytes,
        onDownload: () => downloadRequested = true,
      );
      final container = await checkedContainerWithApk(
        androidApkUrl: 'http://cdn.example.com/x.apk',
        adapter: adapter,
      );

      await container.read(updateCheckProvider.notifier).downloadAndInstall();

      final download = downloadStateOf(container);
      expect(download.status, UpdateDownloadStatus.failed);
      expect(download.errorCode, UpdateErrorCode.insecureUrl);
      expect(downloadRequested, isFalse, reason: '拦截后不得发起下载');
    });

    test('sha256 匹配 → completed，返回安装包路径', () async {
      final container = await checkedContainerWithApk(
        androidApkUrl: 'https://cdn.example.com/synlen.apk',
        sha256: sha256.convert(apkBytes).toString(),
      );

      await container.read(updateCheckProvider.notifier).downloadAndInstall();

      final download = downloadStateOf(container);
      expect(download.status, UpdateDownloadStatus.completed);
      expect(download.progress, 1);
      expect(download.apkPath, isNotNull);
      expect(File(download.apkPath!).existsSync(), isTrue);
    });

    test('sha256 不匹配 → checksumMismatch，安装包被删除', () async {
      final container = await checkedContainerWithApk(
        androidApkUrl: 'https://cdn.example.com/synlen.apk',
        sha256: 'ff' * 32,
      );

      await container.read(updateCheckProvider.notifier).downloadAndInstall();

      final download = downloadStateOf(container);
      expect(download.status, UpdateDownloadStatus.failed);
      expect(download.errorCode, UpdateErrorCode.checksumMismatch);
      expect(
        Directory('${cacheDir.path}/apk').listSync(),
        isEmpty,
        reason: '校验失败的安装包必须删除',
      );
    });

    test('清单未提供 sha256 → 放行下载（兼容旧清单）', () async {
      final container = await checkedContainerWithApk(
        androidApkUrl: 'https://cdn.example.com/synlen.apk',
      );

      await container.read(updateCheckProvider.notifier).downloadAndInstall();

      expect(downloadStateOf(container).status, UpdateDownloadStatus.completed);
    });

    test('下载网络失败 → downloadFailed', () async {
      final container = await checkedContainerWithApk(
        androidApkUrl: 'https://cdn.example.com/synlen.apk',
        failDownload: true,
      );

      await container.read(updateCheckProvider.notifier).downloadAndInstall();

      final download = downloadStateOf(container);
      expect(download.status, UpdateDownloadStatus.failed);
      expect(download.errorCode, UpdateErrorCode.downloadFailed);
    });
  });
}

/// 固定响应清单与 APK 字节的 HttpClientAdapter。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({
    required this.manifestBody,
    this.apkBytes,
    this.failManifestWith,
    this.failDownload = false,
    this.onDownload,
  });

  final String manifestBody;
  final Uint8List? apkBytes;
  final DioException? failManifestWith;
  final bool failDownload;
  final void Function()? onDownload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (options.uri.path.endsWith('version.json')) {
      final failure = failManifestWith;
      if (failure != null) return Future.error(failure);
      return Future.value(ResponseBody.fromString(manifestBody, 200));
    }
    onDownload?.call();
    if (failDownload) {
      return Future.error(
        DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
    }
    return Future.value(ResponseBody.fromBytes(apkBytes ?? Uint8List(0), 200));
  }

  @override
  void close({bool force = false}) {}
}
