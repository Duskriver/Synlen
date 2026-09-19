import 'dart:async';
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
        updateServiceProvider.overrideWith((ref) {
          ref.onDispose(() => dio.close(force: true));
          return UpdateService(
            dio: dio,
            versionEndpoint: 'https://updates.example.com/version.json',
            readPackageInfo: () async => packageInfo ?? defaultLocal,
            cacheDirectory: () async => cacheDir,
          );
        }),
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
    test('清单响应跨过自动释放时机仍能完成检查', () async {
      final adapter = _PendingAdapter();
      final container = containerWith(adapter: adapter);
      final checking = container
          .read(updateCheckProvider.notifier)
          .checkForUpdates();

      await adapter.started.future;
      await container.pump();
      adapter.respond(ResponseBody.fromString(manifestJson(), 200));
      await checking;

      final state = container.read(updateCheckProvider);
      expect(
        state.asData?.value.checkStatus,
        UpdateCheckStatus.upToDate,
        reason: '${state.error}',
      );
      expect(adapter.isClosed, isFalse);
    });

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

    test('构建号与清单同口径直接比较，五位数不被截断', () async {
      // v1.0.0 的构建号派生为 10000。此前的取余归一化会把它截成 0，
      // 使已是最新的用户被反复提示更新——这个用例守住不再归一化。
      final same = await check(
        manifestJson(major: 1, minor: 0, build: 10000),
        packageInfo: localInfo('1.0.0', '10000'),
      );
      expect(same.asData!.value.checkStatus, UpdateCheckStatus.upToDate);

      // 构建号前进一位 → 真有更新
      final newer = await check(
        manifestJson(major: 1, minor: 0, build: 10001),
        packageInfo: localInfo('1.0.0', '10000'),
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
      expect(download.apkRelativePath, isNotNull);
      expect(
        File('${cacheDir.path}/${download.apkRelativePath!}').path,
        download.apkPath,
        reason: '安装 URI 拼的相对路径必须与下载落点一致',
      );
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

    test('APK 响应跨过自动释放时机仍能完成下载与校验', () async {
      final adapter = _PendingAdapter(
        manifestBody: manifestJson(
          minor: 2,
          androidApkSha256: sha256.convert(apkBytes).toString(),
        ),
      );
      final container = containerWith(adapter: adapter);
      await container.read(updateCheckProvider.notifier).checkForUpdates();
      final downloading = container
          .read(updateCheckProvider.notifier)
          .downloadAndInstall();

      await Future.any([adapter.started.future, downloading]);
      await container.pump();
      adapter.respond(ResponseBody.fromBytes(apkBytes, 200));
      await downloading;

      final download = downloadStateOf(container);
      expect(
        download.status,
        UpdateDownloadStatus.completed,
        reason: '${download.errorCode}',
      );
      expect(File(download.apkPath!).readAsBytesSync(), apkBytes);
      expect(adapter.isClosed, isFalse);
    });
  });

  test('更新入口关闭后释放服务，重新进入可再次检查', () async {
    var created = 0;
    var disposed = 0;
    final container = ProviderContainer.test(
      overrides: [
        updateServiceProvider.overrideWith((ref) {
          created++;
          final dio = Dio()
            ..httpClientAdapter = _StubAdapter(manifestBody: manifestJson());
          ref.onDispose(() {
            disposed++;
            dio.close(force: true);
          });
          return UpdateService(
            dio: dio,
            versionEndpoint: 'https://updates.example.com/version.json',
            readPackageInfo: () async => defaultLocal,
            cacheDirectory: () async => cacheDir,
          );
        }),
      ],
    );

    for (var visit = 1; visit <= 2; visit++) {
      final subscription = container.listen(updateCheckProvider, (_, _) {});
      await container.read(updateCheckProvider.notifier).checkForUpdates();
      await container.pump();
      expect(created, visit);
      expect(disposed, visit - 1);
      expect(
        container.read(updateCheckProvider).asData?.value.checkStatus,
        UpdateCheckStatus.upToDate,
      );

      subscription.close();
      await container.pump();
      expect(disposed, visit);
    }
  });

  for (final downloading in [false, true]) {
    test('${downloading ? '下载' : '检查'}期间销毁检查器会关闭连接且不再写状态', () async {
      final adapter = _PendingAdapter(
        manifestBody: downloading ? manifestJson(minor: 2) : null,
      );
      final container = containerWith(adapter: adapter);
      final notifier = container.read(updateCheckProvider.notifier);
      if (downloading) await notifier.checkForUpdates();
      final operation = downloading
          ? notifier.downloadAndInstall()
          : notifier.checkForUpdates();
      await adapter.started.future;

      container.dispose();

      await expectLater(operation, completes);
      expect(adapter.isClosed, isTrue);
    });
  }
}

/// 延迟响应越过 provider 释放时机；强制关闭时中断请求，与真实 Dio 一致。
class _PendingAdapter implements HttpClientAdapter {
  _PendingAdapter({this.manifestBody});

  final String? manifestBody;
  final started = Completer<void>();
  final _response = Completer<ResponseBody>();
  bool isClosed = false;

  void respond(ResponseBody response) {
    if (!_response.isCompleted) _response.complete(response);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    if (isClosed) {
      if (!started.isCompleted) started.complete();
      return Future.error(StateError('HTTP adapter closed before request'));
    }
    final manifest = manifestBody;
    if (manifest != null && options.uri.path.endsWith('version.json')) {
      return Future.value(ResponseBody.fromString(manifest, 200));
    }
    started.complete();
    return _response.future;
  }

  @override
  void close({bool force = false}) {
    isClosed = true;
    if (force && !_response.isCompleted && started.isCompleted) {
      _response.completeError(StateError('HTTP adapter closed during request'));
    }
  }
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
