// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deep_seek_connectivity.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
/// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。

@ProviderFor(DeepSeekKeyCheck)
final deepSeekKeyCheckProvider = DeepSeekKeyCheckProvider._();

/// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
/// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。
final class DeepSeekKeyCheckProvider
    extends
        $NotifierProvider<DeepSeekKeyCheck, AsyncValue<DeepSeekConnectivity?>> {
  /// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
  /// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。
  DeepSeekKeyCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deepSeekKeyCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deepSeekKeyCheckHash();

  @$internal
  @override
  DeepSeekKeyCheck create() => DeepSeekKeyCheck();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<DeepSeekConnectivity?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<DeepSeekConnectivity?>>(
        value,
      ),
    );
  }
}

String _$deepSeekKeyCheckHash() => r'bdbac087657d58fadec702d51e299b44047c5481';

/// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
/// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。

abstract class _$DeepSeekKeyCheck
    extends $Notifier<AsyncValue<DeepSeekConnectivity?>> {
  AsyncValue<DeepSeekConnectivity?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DeepSeekConnectivity?>,
              AsyncValue<DeepSeekConnectivity?>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DeepSeekConnectivity?>,
                AsyncValue<DeepSeekConnectivity?>
              >,
              AsyncValue<DeepSeekConnectivity?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
