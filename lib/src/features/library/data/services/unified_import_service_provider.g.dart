// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_import_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for UnifiedImportService
///
/// This service provides a unified interface for importing EPUB files
/// across different platforms (Android SAF and iOS file system).
///
/// Features:
/// - Pick multiple EPUB files
/// - Pick folder and scan for EPUB files recursively
/// - Process files into cached, hashed ImportableEpub objects
/// - Platform-agnostic API with native performance

@ProviderFor(unifiedImportService)
final unifiedImportServiceProvider = UnifiedImportServiceProvider._();

/// Provider for UnifiedImportService
///
/// This service provides a unified interface for importing EPUB files
/// across different platforms (Android SAF and iOS file system).
///
/// Features:
/// - Pick multiple EPUB files
/// - Pick folder and scan for EPUB files recursively
/// - Process files into cached, hashed ImportableEpub objects
/// - Platform-agnostic API with native performance

final class UnifiedImportServiceProvider
    extends
        $FunctionalProvider<
          UnifiedImportService,
          UnifiedImportService,
          UnifiedImportService
        >
    with $Provider<UnifiedImportService> {
  /// Provider for UnifiedImportService
  ///
  /// This service provides a unified interface for importing EPUB files
  /// across different platforms (Android SAF and iOS file system).
  ///
  /// Features:
  /// - Pick multiple EPUB files
  /// - Pick folder and scan for EPUB files recursively
  /// - Process files into cached, hashed ImportableEpub objects
  /// - Platform-agnostic API with native performance
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
    r'0c1ecd50c896e25b2f150c0ea04b1f194926c670';

/// Provider for ImportCacheManager
///
/// Manages the import cache directory and file operations.
/// Can be used directly if you need lower-level cache management.

@ProviderFor(importCacheManager)
final importCacheManagerProvider = ImportCacheManagerProvider._();

/// Provider for ImportCacheManager
///
/// Manages the import cache directory and file operations.
/// Can be used directly if you need lower-level cache management.

final class ImportCacheManagerProvider
    extends
        $FunctionalProvider<
          ImportCacheManager,
          ImportCacheManager,
          ImportCacheManager
        >
    with $Provider<ImportCacheManager> {
  /// Provider for ImportCacheManager
  ///
  /// Manages the import cache directory and file operations.
  /// Can be used directly if you need lower-level cache management.
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
    r'f04a068bb0a002bd1962690296a6659e8d5cb92a';
