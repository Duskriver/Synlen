// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_check.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 更新检查与安装用例；插件事件和异常只在此转成类型化状态。

@ProviderFor(UpdateCheck)
final updateCheckProvider = UpdateCheckProvider._();

/// 更新检查与安装用例；插件事件和异常只在此转成类型化状态。
final class UpdateCheckProvider
    extends $NotifierProvider<UpdateCheck, AsyncValue<UpdateState>> {
  /// 更新检查与安装用例；插件事件和异常只在此转成类型化状态。
  UpdateCheckProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateCheckProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateCheckHash();

  @$internal
  @override
  UpdateCheck create() => UpdateCheck();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<UpdateState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<UpdateState>>(value),
    );
  }
}

String _$updateCheckHash() => r'60b99d9e81635842b4743d71264a5fead6ca72dc';

/// 更新检查与安装用例；插件事件和异常只在此转成类型化状态。

abstract class _$UpdateCheck extends $Notifier<AsyncValue<UpdateState>> {
  AsyncValue<UpdateState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<UpdateState>, AsyncValue<UpdateState>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UpdateState>, AsyncValue<UpdateState>>,
              AsyncValue<UpdateState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
