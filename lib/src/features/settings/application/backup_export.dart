import 'dart:ui' show Rect;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service_provider.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

part 'backup_export.g.dart';

/// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
/// data 层的服务与结果类型不外泄到 UI。
@riverpod
class BackupExport extends _$BackupExport {
  @override
  void build() {
    ref.watch(exportBackupServiceProvider);
  }

  /// 成功返回 null；取消或失败只返回错误码，异常详情只入日志。
  Future<LibraryErrorCode?> exportToShareSheet({
    Rect? sharePositionOrigin,
    required String shareTitle,
  }) async {
    try {
      final result = await ref
          .read(exportBackupServiceProvider)
          .exportLibraryAsFile(
            sharePositionOrigin: sharePositionOrigin,
            shareTitle: shareTitle,
          );
      return switch (result) {
        ExportSuccess() => null,
        ExportFailure(:final code) => code,
      };
    } catch (error, stackTrace) {
      appLogger.e('备份导出失败', error: error, stackTrace: stackTrace);
      return LibraryErrorCode.exportFailed;
    }
  }
}
