// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供 [UpdateService] 实例；清单端点见 [AppInfo.versionEndpoint]。

@ProviderFor(updateService)
final updateServiceProvider = UpdateServiceProvider._();

/// 提供 [UpdateService] 实例；清单端点见 [AppInfo.versionEndpoint]。

final class UpdateServiceProvider
    extends $FunctionalProvider<UpdateService, UpdateService, UpdateService>
    with $Provider<UpdateService> {
  /// 提供 [UpdateService] 实例；清单端点见 [AppInfo.versionEndpoint]。
  UpdateServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateServiceHash();

  @$internal
  @override
  $ProviderElement<UpdateService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UpdateService create(Ref ref) {
    return updateService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UpdateService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UpdateService>(value),
    );
  }
}

String _$updateServiceHash() => r'11fb54b25a13d61f75dbf0e157c16b981de7d3a9';
