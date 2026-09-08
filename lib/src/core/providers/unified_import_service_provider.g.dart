// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_import_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 统一导入服务的 provider：跨 Android SAF / iOS 文件系统提供同一套选书与入缓存接口。
///
/// 能力：多选文件、选文件夹递归扫描、把选中文件转成带哈希的 ImportableEpub。
/// 该服务被 library、settings 与分享入口共同消费，因此 provider 落在 core/providers。

@ProviderFor(unifiedImportService)
final unifiedImportServiceProvider = UnifiedImportServiceProvider._();

/// 统一导入服务的 provider：跨 Android SAF / iOS 文件系统提供同一套选书与入缓存接口。
///
/// 能力：多选文件、选文件夹递归扫描、把选中文件转成带哈希的 ImportableEpub。
/// 该服务被 library、settings 与分享入口共同消费，因此 provider 落在 core/providers。

final class UnifiedImportServiceProvider
    extends
        $FunctionalProvider<
          UnifiedImportService,
          UnifiedImportService,
          UnifiedImportService
        >
    with $Provider<UnifiedImportService> {
  /// 统一导入服务的 provider：跨 Android SAF / iOS 文件系统提供同一套选书与入缓存接口。
  ///
  /// 能力：多选文件、选文件夹递归扫描、把选中文件转成带哈希的 ImportableEpub。
  /// 该服务被 library、settings 与分享入口共同消费，因此 provider 落在 core/providers。
  UnifiedImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unifiedImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unifiedImportServiceHash();

  @$internal
  @override
  $ProviderElement<UnifiedImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UnifiedImportService create(Ref ref) {
    return unifiedImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnifiedImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnifiedImportService>(value),
    );
  }
}

String _$unifiedImportServiceHash() =>
    r'ab8e62d4d7a2172d38a043c68f2a69fe28fe2506';

/// 导入缓存目录与文件操作的 provider；需要更底层的缓存管理时可直接使用。

@ProviderFor(importCacheManager)
final importCacheManagerProvider = ImportCacheManagerProvider._();

/// 导入缓存目录与文件操作的 provider；需要更底层的缓存管理时可直接使用。

final class ImportCacheManagerProvider
    extends
        $FunctionalProvider<
          ImportCacheManager,
          ImportCacheManager,
          ImportCacheManager
        >
    with $Provider<ImportCacheManager> {
  /// 导入缓存目录与文件操作的 provider；需要更底层的缓存管理时可直接使用。
  ImportCacheManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importCacheManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importCacheManagerHash();

  @$internal
  @override
  $ProviderElement<ImportCacheManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImportCacheManager create(Ref ref) {
    return importCacheManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImportCacheManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImportCacheManager>(value),
    );
  }
}

String _$importCacheManagerHash() =>
    r'4deec75b89537584bc3db1c2b155ba69564f62c8';
