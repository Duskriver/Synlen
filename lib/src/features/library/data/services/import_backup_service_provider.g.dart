// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_backup_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 注入恢复所需的书目读取、跨表事务与平台文件入口。

@ProviderFor(importBackupService)
final importBackupServiceProvider = ImportBackupServiceProvider._();

/// 注入恢复所需的书目读取、跨表事务与平台文件入口。

final class ImportBackupServiceProvider
    extends
        $FunctionalProvider<
          ImportBackupService,
          ImportBackupService,
          ImportBackupService
        >
    with $Provider<ImportBackupService> {
  /// 注入恢复所需的书目读取、跨表事务与平台文件入口。
  ImportBackupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importBackupServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importBackupServiceHash();

  @$internal
  @override
  $ProviderElement<ImportBackupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImportBackupService create(Ref ref) {
    return importBackupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportBackupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportBackupService>(value),
    );
  }
}

String _$importBackupServiceHash() =>
    r'5a9efd7a11678bc2150005991b446a0796437e69';
