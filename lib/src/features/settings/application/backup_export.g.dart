// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_export.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
/// data 层的服务与结果类型不外泄到 UI。

@ProviderFor(BackupExport)
final backupExportProvider = BackupExportProvider._();

/// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
/// data 层的服务与结果类型不外泄到 UI。
final class BackupExportProvider extends $NotifierProvider<BackupExport, void> {
  /// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
  /// data 层的服务与结果类型不外泄到 UI。
  BackupExportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backupExportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backupExportHash();

  @$internal
  @override
  BackupExport create() => BackupExport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$backupExportHash() => r'f271537e8e7103e7aeb691b22c6065bc94f9a8f0';

/// 整库备份导出用例（组合面）。presentation 只说「导到分享面板」，
/// data 层的服务与结果类型不外泄到 UI。

abstract class _$BackupExport extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
