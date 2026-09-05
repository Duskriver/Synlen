// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 用户自填密钥存于系统安全存储，不写入源码或构建配置。

@ProviderFor(apiKeyStorage)
final apiKeyStorageProvider = ApiKeyStorageProvider._();

/// 用户自填密钥存于系统安全存储，不写入源码或构建配置。

final class ApiKeyStorageProvider
    extends
        $FunctionalProvider<
          FlutterSecureStorage,
          FlutterSecureStorage,
          FlutterSecureStorage
        >
    with $Provider<FlutterSecureStorage> {
  /// 用户自填密钥存于系统安全存储，不写入源码或构建配置。
  ApiKeyStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiKeyStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiKeyStorageHash();

  @$internal
  @override
  $ProviderElement<FlutterSecureStorage> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FlutterSecureStorage create(Ref ref) {
    return apiKeyStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlutterSecureStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlutterSecureStorage>(value),
    );
  }
}

String _$apiKeyStorageHash() => r'2a161e79ce3809a8f987ad1bd20224d9d8d926da';
