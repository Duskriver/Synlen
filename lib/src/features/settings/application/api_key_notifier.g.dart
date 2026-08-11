// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AI 服务（DeepSeek / 阿里云 TTS）的 API Key 配置。
///
/// 密钥由用户自己在设置页填写，存于 [FlutterSecureStorage]（系统安全存储），
/// 不写入源码与构建产物，保证开源分发不含任何密钥。

@ProviderFor(ApiKeyNotifier)
final apiKeyProvider = ApiKeyNotifierProvider._();

/// AI 服务（DeepSeek / 阿里云 TTS）的 API Key 配置。
///
/// 密钥由用户自己在设置页填写，存于 [FlutterSecureStorage]（系统安全存储），
/// 不写入源码与构建产物，保证开源分发不含任何密钥。
final class ApiKeyNotifierProvider
    extends $NotifierProvider<ApiKeyNotifier, ApiKeyConfig> {
  /// AI 服务（DeepSeek / 阿里云 TTS）的 API Key 配置。
  ///
  /// 密钥由用户自己在设置页填写，存于 [FlutterSecureStorage]（系统安全存储），
  /// 不写入源码与构建产物，保证开源分发不含任何密钥。
  ApiKeyNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiKeyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiKeyNotifierHash();

  @$internal
  @override
  ApiKeyNotifier create() => ApiKeyNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiKeyConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiKeyConfig>(value),
    );
  }
}

String _$apiKeyNotifierHash() => r'b934cc74eeb3dc763ecb220349d215b60d07a6a0';

/// AI 服务（DeepSeek / 阿里云 TTS）的 API Key 配置。
///
/// 密钥由用户自己在设置页填写，存于 [FlutterSecureStorage]（系统安全存储），
/// 不写入源码与构建产物，保证开源分发不含任何密钥。

abstract class _$ApiKeyNotifier extends $Notifier<ApiKeyConfig> {
  ApiKeyConfig build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ApiKeyConfig, ApiKeyConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ApiKeyConfig, ApiKeyConfig>,
              ApiKeyConfig,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
