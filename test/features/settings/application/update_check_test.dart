import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/features/settings/application/update_check.dart';
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';
import 'package:synlen/src/features/settings/domain/update_exception.dart';

void main() {
  late Directory directory;
  late _ManifestAdapter adapter;
  late Future<Directory> Function() supportDirectory;
  late List<_FakeUpdater> updaters;
  late ProviderContainer container;
  late ProviderSubscription<AsyncValue<UpdateState>> subscription;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('update_check');
    adapter = _ManifestAdapter();
    supportDirectory = () async => directory;
    updaters = [];
    container = ProviderContainer.test(
      overrides: [
        updateServiceProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          ref.onDispose(() => dio.close(force: true));
          return UpdateService(
            dio: dio,
            versionEndpoint: 'https://updates.example.com/version.json',
            readPackageInfo: () async => PackageInfo(
              appName: 'Synlen',
              packageName: 'com.tanglei.synlen',
              version: '1.0.0',
              buildNumber: '10000',
            ),
            supportDirectory: () => supportDirectory(),
            createUpdater: () {
              final updater = _FakeUpdater();
              updaters.add(updater);
              return updater;
            },
          );
        }),
      ],
    );
    subscription = container.listen(updateCheckProvider, (_, _) {});
  });

  tearDown(() async {
    for (final updater in updaters) {
      await updater.events.close();
    }
    await directory.delete(recursive: true);
  });

  UpdateCheck notifier() => container.read(updateCheckProvider.notifier);
  UpdateState state() => container.read(updateCheckProvider).asData!.value;
  Future<void> check() => notifier().checkForUpdates();
  Future<void> tick() => Future<void>.delayed(Duration.zero);
  Future<void> waitForUpdater([int count = 1]) async {
    while (updaters.length < count) {
      await tick();
    }
  }

  Future<void> emit(OtaStatus status, [String? value]) async {
    updaters.last.events.add(OtaEvent(status, value));
    await tick();
  }

  Future<void> finish(OtaStatus status, [String? value]) async {
    await emit(status, value);
    await updaters.last.events.close();
  }

  for (final cancelFails in [true, false]) {
    for (final terminal in [
      OtaStatus.INSTALLING,
      OtaStatus.DOWNLOAD_ERROR,
      OtaStatus.CANCELED,
      null,
    ]) {
      test('取消回执失败=$cancelFails，流以 $terminal 结束后仍可关闭或重试', () async {
        await check();
        final operation = notifier().downloadAndInstall();
        await waitForUpdater();
        final updater = updaters.single;
        updater.cancellation = Completer<void>();
        final cancel = notifier().cancelDownload();
        if (terminal != null) await emit(terminal);
        await updater.events.close();
        await operation;
        // 原生取消尚未完成，即使流结束也不能开放新的下载。
        expect(state().download.status, UpdateDownloadStatus.canceling);
        await notifier().downloadAndInstall();
        expect(updaters, hasLength(1));
        if (cancelFails) {
          updater.cancellation!.completeError(
            StateError('cancel channel failed'),
          );
        } else {
          updater.cancellation!.complete();
        }
        await cancel;
        final expected = terminal == OtaStatus.INSTALLING
            ? UpdateDownloadStatus.installerOpened
            : !cancelFails || terminal == OtaStatus.CANCELED
            ? UpdateDownloadStatus.canceled
            : UpdateDownloadStatus.failed;
        expect(state().download.status, expected);
        await notifier().cancelDownload();
        expect(state().download.isBusy, isFalse);
        final retry = notifier().downloadAndInstall();
        await waitForUpdater(2);
        await finish(OtaStatus.INSTALLING);
        await retry;
      });
    }
  }

  test('高版本保留清单和更新说明；相同或较低版本不提示更新', () async {
    await check();
    expect(state().checkStatus, UpdateCheckStatus.updateAvailable);
    expect(state().manifest!.updateLog, '修复问题');
    expect(state().manifest!.androidApkSha256, 'ab' * 32);
    adapter.build = 10000;
    await check();
    expect(state().checkStatus, UpdateCheckStatus.upToDate);
    adapter.major = 0;
    adapter.build = 99999;
    await check();
    expect(state().checkStatus, UpdateCheckStatus.upToDate);
  });

  for (final body in ['{"code":500}', 'bad json', '{"code":200,"data":{}}']) {
    test('无效清单转为检查错误：$body', () async {
      adapter.body = body;
      await check();
      final error =
          container.read(updateCheckProvider).error as UpdateException;
      expect(error.code, UpdateErrorCode.checkFailed);
    });
  }

  test('网络失败可重新检查', () async {
    adapter.fail = true;
    await check();
    expect(container.read(updateCheckProvider).hasError, isTrue);
    adapter.fail = false;
    await check();
    expect(state().checkStatus, UpdateCheckStatus.updateAvailable);
  });

  test('检查等待期间服务保持存活，重复检查不发请求', () async {
    adapter.pending = Completer<ResponseBody>();
    final checking = check();
    await adapter.started.future;
    await check();
    await container.pump();
    expect(adapter.requests, 1);
    expect(adapter.closed, isFalse);
    adapter.pending!.complete(ResponseBody.fromString(adapter.json, 200));
    await checking;
    expect(state().checkStatus, UpdateCheckStatus.updateAvailable);
  });

  test('退出释放服务；检查中的迟到结果不写状态', () async {
    adapter.pending = Completer<ResponseBody>();
    final checking = check();
    await adapter.started.future;
    subscription.close();
    await container.pump();
    expect(adapter.closed, isTrue);
    await expectLater(checking, completes);
  });

  for (final (url, hash, code) in [
    ('', 'ab' * 32, UpdateErrorCode.noUpdateChannel),
    ('http://cdn.example.com/a.apk', 'ab' * 32, UpdateErrorCode.insecureUrl),
    ('https://cdn.example.com/a.apk', '', UpdateErrorCode.invalidChecksum),
    (
      'https://cdn.example.com/a.apk',
      'not-a-hash',
      UpdateErrorCode.invalidChecksum,
    ),
  ]) {
    test('下载前拒绝无效渠道或摘要：$code $hash', () async {
      adapter.url = url;
      adapter.checksum = hash;
      await check();
      await notifier().downloadAndInstall();
      expect(state().download.errorCode, code);
      expect(updaters, isEmpty);
    });
  }

  test('向插件传直链、固定文件名、规范摘要，下载期间阻止重新检查和重复下载', () async {
    adapter.checksum = '  ${'AB' * 32}  ';
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    await notifier().downloadAndInstall();
    await check();
    expect(adapter.requests, 1);
    expect(updaters, hasLength(1));
    final updater = updaters.single;
    expect(updater.url, adapter.url);
    expect(updater.filename, 'synlen-update.apk');
    expect(updater.checksum, 'ab' * 32);
    expect(updater.packageInstaller, isFalse);
    expect(state().download.progress, isNull);
    await emit(OtaStatus.DOWNLOADING, '42');
    expect(state().download.progress, .42);
    await emit(OtaStatus.DOWNLOADING, 'NaN');
    expect(state().download.progress, isNull);
    await emit(OtaStatus.DOWNLOADING, '120');
    expect(state().download.progress, 1);
    await finish(OtaStatus.INSTALLING);
    await operation;
    expect(state().download.status, UpdateDownloadStatus.installerOpened);
  });

  for (final (event, code) in [
    (OtaStatus.DOWNLOAD_ERROR, UpdateErrorCode.downloadFailed),
    (OtaStatus.INTERNAL_ERROR, UpdateErrorCode.downloadFailed),
    (OtaStatus.INSTALLATION_ERROR, UpdateErrorCode.installFailed),
    (OtaStatus.ALREADY_RUNNING_ERROR, UpdateErrorCode.installFailed),
    (
      OtaStatus.PERMISSION_NOT_GRANTED_ERROR,
      UpdateErrorCode.installPermissionDenied,
    ),
  ]) {
    test('$event 保留清单并转为 $code，重试使用新实例', () async {
      await check();
      final manifest = state().manifest;
      final operation = notifier().downloadAndInstall();
      await waitForUpdater();
      await finish(event, '内部错误细节');
      await operation;
      expect(state().download.status, UpdateDownloadStatus.failed);
      expect(state().download.errorCode, code);
      expect(state().manifest, same(manifest));
      final retry = notifier().downloadAndInstall();
      await waitForUpdater(2);
      expect(updaters, hasLength(2));
      await finish(OtaStatus.INSTALLING);
      await retry;
      expect(state().download.status, UpdateDownloadStatus.installerOpened);
    });
  }

  test('插件报告摘要失败时删除私有目录内的坏包', () async {
    await check();
    final file = File('${directory.path}/ota_update/synlen-update.apk');
    await file.parent.create();
    await file.writeAsString('invalid apk');
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    await finish(OtaStatus.CHECKSUM_ERROR);
    await operation;
    expect(state().download.errorCode, UpdateErrorCode.checksumMismatch);
    expect(await file.exists(), isFalse);
  });

  test('流意外结束不误报安装成功', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    await updaters.single.events.close();
    await operation;
    expect(state().download.errorCode, UpdateErrorCode.downloadFailed);
  });

  test('流异常转成下载失败', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    updaters.single.events.addError(StateError('channel failure'));
    await operation;
    expect(state().download.errorCode, UpdateErrorCode.downloadFailed);
  });

  test('取消等待原生确认，忽略迟到事件，结束后允许新实例重试', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    final updater = updaters.single;
    updater.cancellation = Completer<void>();
    final cancel = notifier().cancelDownload();
    expect(state().download.status, UpdateDownloadStatus.canceling);
    await notifier().downloadAndInstall();
    await check();
    expect(updaters, hasLength(1));
    await emit(OtaStatus.DOWNLOAD_ERROR, 'canceled socket');
    updater.cancellation!.complete();
    await cancel;
    await operation;
    expect(updater.cancelCount, 1);
    expect(state().download.status, UpdateDownloadStatus.canceled);
    final retry = notifier().downloadAndInstall();
    await waitForUpdater(2);
    await finish(OtaStatus.INSTALLING);
    await retry;
    expect(updaters, hasLength(2));
  });

  test('准备记录期间取消不会在异步写入后启动插件', () async {
    await check();
    final preparing = Completer<Directory>();
    supportDirectory = () => preparing.future;
    final operation = notifier().downloadAndInstall();
    final cancel = notifier().cancelDownload();
    preparing.complete(directory);
    await cancel;
    await operation;
    expect(updaters, isEmpty);
    expect(state().download.status, UpdateDownloadStatus.canceled);
  });

  test('坏包清理失败保留原始校验错误和记录，启动回收可重试', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    final file = File('${directory.path}/ota_update/synlen-update.apk');
    final record = File('${directory.path}/ota_update/pending.json');
    await file.writeAsString('bad APK');
    supportDirectory = () => Future.error(FileSystemException('unavailable'));
    await finish(OtaStatus.CHECKSUM_ERROR);
    await operation;
    expect(state().download.errorCode, UpdateErrorCode.checksumMismatch);
    expect(await file.exists(), isTrue);
    expect(await record.exists(), isTrue);
    supportDirectory = () async => directory;
    await container.read(updateServiceProvider).cleanupDownloadedApk();
    expect(await file.exists(), isFalse);
    expect(await record.exists(), isFalse);
  });

  test('取消等待中释放 provider 不重复取消原生任务', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    final updater = updaters.single;
    updater.cancellation = Completer<void>();
    final cancel = notifier().cancelDownload();
    subscription.close();
    await container.pump();
    updater.cancellation!.complete();
    await cancel;
    await operation;
    expect(updater.cancelCount, 1);
    expect(updater.events.hasListener, isFalse);
  });

  test('记录写入失败不得开始下载', () async {
    await check();
    await File('${directory.path}/ota_update').writeAsString('blocked');
    await notifier().downloadAndInstall();
    expect(updaters, isEmpty);
    expect(state().download.errorCode, UpdateErrorCode.downloadFailed);
  });

  test('取消失败不删除 APK，确认取消后保留记录供启动回收', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    final file = File('${directory.path}/ota_update/synlen-update.apk');
    final record = File('${directory.path}/ota_update/pending.json');
    await file.writeAsString('partial');
    updaters.single.cancelFails = true;
    await notifier().cancelDownload();
    expect(await file.exists(), isTrue);
    expect(await record.exists(), isTrue);
    updaters.single.cancelFails = false;
    await notifier().cancelDownload();
    await operation;
    expect(await file.exists(), isTrue);
    expect(await record.exists(), isTrue);
  });

  test('安装器打开后退出页面保留 APK 和记录，不再取消原生任务', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    final file = File('${directory.path}/ota_update/synlen-update.apk');
    await file.writeAsString('complete');
    await finish(OtaStatus.INSTALLING);
    await operation;
    subscription.close();
    await container.pump();
    expect(await file.exists(), isTrue);
    expect(
      await File('${directory.path}/ota_update/pending.json').exists(),
      isTrue,
    );
    expect(updaters.single.cancelCount, 0);
  });

  test('下载期间释放 provider 取消原生下载和事件订阅', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    subscription.close();
    await container.pump();
    await operation;
    expect(updaters.single.cancelCount, 1);
    expect(updaters.single.events.hasListener, isFalse);
    expect(adapter.closed, isTrue);
  });

  test('取消调用失败时保留下载，允许再次取消', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    updaters.single.cancelFails = true;
    await notifier().cancelDownload();
    expect(state().download.isBusy, isTrue);
    updaters.single.cancelFails = false;
    await notifier().cancelDownload();
    await operation;
    expect(state().download.status, UpdateDownloadStatus.canceled);
  });

  test('释放时即使原生取消失败也关闭 Dart 订阅', () async {
    await check();
    final operation = notifier().downloadAndInstall();
    await waitForUpdater();
    updaters.single.cancelFails = true;
    subscription.close();
    await container.pump();
    await operation;
    expect(updaters.single.events.hasListener, isFalse);
  });
}

class _FakeUpdater extends OtaUpdate {
  final events = StreamController<OtaEvent>();
  String? url;
  String? filename;
  String? checksum;
  bool? packageInstaller;
  int cancelCount = 0;
  bool cancelFails = false;
  Completer<void>? cancellation;

  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const {},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) {
    this.url = url;
    filename = destinationFilename;
    checksum = sha256checksum;
    packageInstaller = usePackageInstaller;
    return events.stream;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
    if (cancelFails) throw StateError('cancel failed');
    await cancellation?.future;
  }
}

class _ManifestAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  int major = 1;
  int build = 10001;
  int requests = 0;
  String url = 'https://cdn.example.com/synlen.apk';
  String checksum = 'ab' * 32;
  String? body;
  bool fail = false;
  bool closed = false;
  Completer<ResponseBody>? pending;

  String get json => jsonEncode({
    'code': 200,
    'data': {
      'majorNumber': major,
      'minorNumber': 0,
      'patchNumber': 0,
      'buildNumber': build,
      'updateLog': '修复问题',
      'androidApkUrl': url,
      'androidApkSha256': checksum,
    },
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (!started.isCompleted) started.complete();
    if (fail) throw StateError('offline');
    if (pending case final response?) return response.future;
    return ResponseBody.fromString(body ?? json, 200);
  }

  @override
  void close({bool force = false}) {
    closed = true;
    final response = pending;
    if (response != null && !response.isCompleted) {
      response.completeError(StateError('closed'));
    }
  }
}
