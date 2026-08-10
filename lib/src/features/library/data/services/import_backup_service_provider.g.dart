// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_backup_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for [ImportBackupService].
///
/// Injects the raw [Isar] instance directly so the service can call
/// index-based upsert methods (`putByFileHash`, `putByName`) that are not
/// exposed through the higher-level repository layer.

@ProviderFor(importBackupService)
final importBackupServiceProvider = ImportBackupServiceProvider._();

/// Provider for [ImportBackupService].
///
/// Injects the raw [Isar] instance directly so the service can call
/// index-based upsert methods (`putByFileHash`, `putByName`) that are not
/// exposed through the higher-level repository layer.

final class ImportBackupServiceProvider
    extends
        $FunctionalProvider<
          ImportBackupService,
          ImportBackupService,
          ImportBackupService
        >
    with $Provider<ImportBackupService> {
  /// Provider for [ImportBackupService].
  ///
  /// Injects the raw [Isar] instance directly so the service can call
  /// index-based upsert methods (`putByFileHash`, `putByName`) that are not
  /// exposed through the higher-level repository layer.
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
    r'e902e3c607bbbf9742c2787965875250a7d9ce1b';
