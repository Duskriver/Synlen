import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service_provider.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';
import 'package:synlen/src/features/settings/application/backup_export.dart';

class _Exporter implements ExportBackupService {
  _Exporter(this.export);
  final Future<ExportResult> Function() export;

  @override
  Future<ExportResult> exportLibraryAsFile({
    Rect? sharePositionOrigin,
    required String shareTitle,
  }) => export();

  @override
  Future<void> clearCache() async {}
}

void main() {
  final outcomes = <ExportResult, LibraryErrorCode?>{
    const ExportSuccess(): null,
    const ExportFailure(LibraryErrorCode.exportCancelled):
        LibraryErrorCode.exportCancelled,
    const ExportFailure(LibraryErrorCode.exportFailed):
        LibraryErrorCode.exportFailed,
  };
  for (final outcome in outcomes.entries) {
    test('备份用例只返回成功或错误码：${outcome.value}', () async {
      final container = ProviderContainer.test(
        overrides: [
          exportBackupServiceProvider.overrideWithValue(
            _Exporter(() async => outcome.key),
          ),
        ],
      );
      container.listen(backupExportProvider, (_, _) {});
      expect(
        await container
            .read(backupExportProvider.notifier)
            .exportToShareSheet(shareTitle: '备份'),
        outcome.value,
      );
    });
  }

  for (final error in [
    const FileSystemException('private device path'),
    PlatformException(
      code: 'SHARE_FAILED',
      message: 'private platform details',
    ),
    StateError('private database details'),
  ]) {
    test('异常转换为导出失败码，不把内部细节返回展示层：${error.runtimeType}', () async {
      final container = ProviderContainer.test(
        overrides: [
          exportBackupServiceProvider.overrideWithValue(
            _Exporter(() async => throw error),
          ),
        ],
      );
      container.listen(backupExportProvider, (_, _) {});
      expect(
        await container
            .read(backupExportProvider.notifier)
            .exportToShareSheet(shareTitle: '备份'),
        LibraryErrorCode.exportFailed,
      );
    });
  }

  test('跨帧等待期间持有服务，页面退订后释放', () async {
    final gate = Completer<ExportResult>();
    var disposed = false;
    final container = ProviderContainer.test(
      overrides: [
        exportBackupServiceProvider.overrideWith((ref) {
          ref.onDispose(() => disposed = true);
          return _Exporter(() => gate.future);
        }),
      ],
    );
    final subscription = container.listen(backupExportProvider, (_, _) {});
    final export = container
        .read(backupExportProvider.notifier)
        .exportToShareSheet(shareTitle: '备份');
    await container.pump();
    expect(disposed, isFalse);
    gate.complete(const ExportSuccess());
    expect(await export, isNull);
    subscription.close();
    await container.pump();
    expect(disposed, isTrue);
  });
}
