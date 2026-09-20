import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:synlen/src/features/settings/application/update_apk_cleanup.dart';
import 'package:synlen/src/features/settings/data/services/update_service.dart';
import 'package:synlen/src/features/settings/data/services/update_service_provider.dart';

void main() {
  late Directory directory;
  late File record;
  late File apk;
  late ProviderContainer container;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('startup_apk_cleanup');
    final updateDirectory = Directory('${directory.path}/ota_update');
    await updateDirectory.create();
    record = File('${updateDirectory.path}/pending.json');
    apk = File('${updateDirectory.path}/synlen-update.apk');
    await apk.writeAsString('old APK');
    container = ProviderContainer.test(
      overrides: [
        updateServiceProvider.overrideWith((ref) {
          final dio = Dio();
          ref.onDispose(dio.close);
          return UpdateService(
            dio: dio,
            versionEndpoint: 'https://example.com/version.json',
            readPackageInfo: () async => PackageInfo(
              appName: 'test',
              packageName: 'test',
              version: '1.0.0',
              buildNumber: '10001',
            ),
            supportDirectory: () async => directory,
            createUpdater: OtaUpdate.new,
          );
        }),
      ],
    );
  });

  tearDown(() async => directory.delete(recursive: true));

  Future<void> writeRecord() => record.writeAsString(
    jsonEncode({
      'major': 1,
      'minor': 0,
      'patch': 0,
      'build': 10001,
      'sha256': 'ab' * 32,
    }),
  );

  test('启动用例完成后已安装的包和记录均已回收', () async {
    await writeRecord();
    expect(await container.read(updateApkCleanupProvider.future), isTrue);
    expect(await apk.exists(), isFalse);
    expect(await record.exists(), isFalse);
  });

  test('清理异常转为失败结果，保留文件和记录，后续启动可重试', () async {
    await record.writeAsString('broken record');
    expect(await container.read(updateApkCleanupProvider.future), isFalse);
    expect(await apk.exists(), isTrue);
    expect(await record.exists(), isTrue);
    await writeRecord();
    container.invalidate(updateApkCleanupProvider);
    expect(await container.read(updateApkCleanupProvider.future), isTrue);
    expect(await apk.exists(), isFalse);
    expect(await record.exists(), isFalse);
  });
}
