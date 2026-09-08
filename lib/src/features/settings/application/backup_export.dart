import 'dart:ui' show Rect;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service_provider.dart';

part 'backup_export.g.dart';

/// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
/// data 层的服务与结果类型不外泄到 UI。
@riverpod
class BackupExport extends _$BackupExport {
  @override
  void build() {}

  /// 导出备份并交给系统分享面板；成功返回 null，失败返回可展示的错误详情。
  Future<String?> exportToShareSheet({
    Rect? sharePositionOrigin,
    required String shareTitle,
  }) async {
    final result = await ref
        .read(exportBackupServiceProvider)
        .exportLibraryAsFile(
          sharePositionOrigin: sharePositionOrigin,
          shareTitle: shareTitle,
        );
    return switch (result) {
      ExportSuccess() => null,
      ExportFailure(:final message) => message,
    };
  }
}
