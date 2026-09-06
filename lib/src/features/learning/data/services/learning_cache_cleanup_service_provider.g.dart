// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learning_cache_cleanup_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for [LearningCacheCleanupService].

@ProviderFor(learningCacheCleanupService)
final learningCacheCleanupServiceProvider =
    LearningCacheCleanupServiceProvider._();

/// Provider for [LearningCacheCleanupService].

final class LearningCacheCleanupServiceProvider
    extends
        $FunctionalProvider<
          LearningCacheCleanupService,
          LearningCacheCleanupService,
          LearningCacheCleanupService
        >
    with $Provider<LearningCacheCleanupService> {
  /// Provider for [LearningCacheCleanupService].
  LearningCacheCleanupServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'learningCacheCleanupServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$learningCacheCleanupServiceHash();

  @$internal
  @override
  $ProviderElement<LearningCacheCleanupService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LearningCacheCleanupService create(Ref ref) {
    return learningCacheCleanupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LearningCacheCleanupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LearningCacheCleanupService>(value),
    );
  }
}

String _$learningCacheCleanupServiceHash() =>
    r'cab4a3ad96d9f856a3534b0894e710c577e6e49f';
