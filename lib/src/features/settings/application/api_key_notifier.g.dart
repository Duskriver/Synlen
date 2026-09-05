// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 密钥加载完成前保持 loading；读取失败不得冒充空配置。

@ProviderFor(ApiKeyNotifier)
final apiKeyProvider = ApiKeyNotifierProvider._();

/// 密钥加载完成前保持 loading；读取失败不得冒充空配置。
final class ApiKeyNotifierProvider
    extends $AsyncNotifierProvider<ApiKeyNotifier, ApiKeyConfig> {
  /// 密钥加载完成前保持 loading；读取失败不得冒充空配置。
  ApiKeyNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: _noApiKeyRetry,
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
}

String _$apiKeyNotifierHash() => r'b82481f591e79cd397e2eceafc7630288ce86a93';

/// 密钥加载完成前保持 loading；读取失败不得冒充空配置。

abstract class _$ApiKeyNotifier extends $AsyncNotifier<ApiKeyConfig> {
  FutureOr<ApiKeyConfig> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ApiKeyConfig>, ApiKeyConfig>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ApiKeyConfig>, ApiKeyConfig>,
              AsyncValue<ApiKeyConfig>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
