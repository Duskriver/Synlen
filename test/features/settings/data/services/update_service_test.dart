import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = EventChannel('sk.fourq.ota_update/stream');
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('update_apk_cleanup');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('真实插件通道收到规范参数，失败关闭后重试重新发起原生 listen', () async {
    final calls = <Map<Object?, Object?>>[];
    final sinks = <MockStreamHandlerEventSink>[];
    var listening = Completer<void>();
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockStreamHandler(channel, null),
    );
    final dio = Dio();
    addTearDown(dio.close);
    final service = UpdateService(
      dio: dio,
      versionEndpoint: 'https://example.com/version.json',
      readPackageInfo: () async => PackageInfo(
        appName: 'test',
        packageName: 'test',
        version: '1.0.0',
        buildNumber: '1',
      ),
      supportDirectory: () async => directory,
      createUpdater: OtaUpdate.new,
    );
    final manifest = VersionManifest(
      major: 1,
      minor: 0,
      patch: 0,
      build: 1,
      androidApkUrl: 'https://example.com/app.apk',
      androidApkSha256: ' ${'AB' * 32} ',
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      listening = Completer<void>();
      binding.defaultBinaryMessenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            calls.add(arguments! as Map<Object?, Object?>);
            sinks.add(events);
            listening.complete();
          },
        ),
      );

      final result = service.downloadAndInstall(manifest).toList();
      await listening.future;
      expect(calls.last['checksum'], 'ab' * 32);
      expect(calls.last['filename'], 'synlen-update.apk');
      expect(calls.last['usePackageInstaller'], 'false');
      if (attempt == 0) {
        sinks.last.error(code: '8', message: 'checksum mismatch');
      } else {
        sinks.last.success(['1', '']);
      }
      sinks.last.endOfStream();
      expect(
        (await result).single.status,
        attempt == 0 ? OtaStatus.CHECKSUM_ERROR : OtaStatus.INSTALLING,
      );
    }
    expect(calls, hasLength(2));
  });

  final bytes = utf8.encode('verified APK fixture');
  final checksum = sha256.convert(bytes).toString();
  VersionManifest manifest() => VersionManifest(
    major: 1,
    minor: 0,
    patch: 0,
    build: 10001,
    androidApkUrl: 'https://example.com/update.apk',
    androidApkSha256: checksum,
  );
  UpdateService service({String version = '1.0.0', String build = '10000'}) {
    final dio = Dio();
    addTearDown(dio.close);
    return UpdateService(
      dio: dio,
      versionEndpoint: 'https://example.com/version.json',
      readPackageInfo: () async => PackageInfo(
        appName: 'test',
        packageName: 'test',
        version: version,
        buildNumber: build,
      ),
      supportDirectory: () async => directory,
      createUpdater: _CompletedUpdater.new,
    );
  }

  File apk() => File('${directory.path}/ota_update/synlen-update.apk');
  File record() => File('${directory.path}/ota_update/pending.json');
  Future<void> download() async {
    await service().downloadAndInstall(manifest()).drain<void>();
    await apk().writeAsBytes(bytes);
  }

  for (final (version, build) in [
    ('1.0.0', '10001'),
    ('1.0.0', '10002'),
    ('1.1.0', '1'),
  ]) {
    test('重启后本地 $version+$build 达到目标，删除包与记录', () async {
      await download();
      await service(version: version, build: build).cleanupDownloadedApk();
      expect(await apk().exists(), isFalse);
      expect(await record().exists(), isFalse);
      await service().cleanupDownloadedApk();
    });
  }

  test('完整待安装包在较低版本重启时保留，重复启动不删除', () async {
    await download();
    await service().cleanupDownloadedApk();
    await service().cleanupDownloadedApk();
    expect(await apk().readAsBytes(), bytes);
    expect(await record().exists(), isTrue);
  });

  test('取消或失败留下的部分文件在重启时删除，不动其他文件', () async {
    await download();
    await apk().writeAsString('partial');
    final other = File('${directory.path}/ota_update/other.apk');
    await other.writeAsString('unrelated');
    await service().cleanupDownloadedApk();
    expect(await apk().exists(), isFalse);
    expect(await record().exists(), isFalse);
    expect(await other.readAsString(), 'unrelated');
  });

  test('文件已删而记录残留，重启可继续完成回收', () async {
    await download();
    await apk().delete();
    await service().cleanupDownloadedApk();
    expect(await record().exists(), isFalse);
  });

  test('没有记录的旧 APK 保守保留', () async {
    await apk().parent.create();
    await apk().writeAsBytes(bytes);
    await service().cleanupDownloadedApk();
    expect(await apk().exists(), isTrue);
  });

  test('临时记录不替换已提交的记录，启动清理临时文件', () async {
    await download();
    final temporary = File('${record().path}.tmp');
    await temporary.writeAsString('incomplete json');
    await service().cleanupDownloadedApk();
    expect(await temporary.exists(), isFalse);
    expect(await apk().exists(), isTrue);
    expect(await record().exists(), isTrue);
  });

  for (final content in [
    'bad json',
    '{}',
    '{"major":1,"minor":0,"patch":0,"build":-1,"sha256":"$checksum"}',
  ]) {
    test('记录损坏时报告异常且保留 APK：$content', () async {
      await download();
      await record().writeAsString(content);
      await expectLater(
        service().cleanupDownloadedApk(),
        throwsA(isA<FormatException>()),
      );
      expect(await apk().exists(), isTrue);
      expect(await record().exists(), isTrue);
    });
  }
}

class _CompletedUpdater extends OtaUpdate {
  @override
  Stream<OtaEvent> execute(
    String url, {
    Map<String, String> headers = const {},
    String? androidProviderAuthority,
    String? destinationFilename,
    String? sha256checksum,
    bool usePackageInstaller = false,
  }) => Stream.value(OtaEvent(OtaStatus.INSTALLING, null));
}
