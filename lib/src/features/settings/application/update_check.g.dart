// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_check.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 更新检查与下载用例：拉取清单、与本地版本比较、下载并校验 APK。
///
/// 错误在此捕获并转成类型化状态（[UpdateErrorCode]），用户可读文案由
/// presentation 按错误码映射 l10n，内部细节只入日志。

@ProviderFor(UpdateCheck)
final updateCheckProvider = UpdateCheckProvider._();

/// 更新检查与下载用例：拉取清单、与本地版本比较、下载并校验 APK。
///
/// 错误在此捕获并转成类型化状态（[UpdateErrorCode]），用户可读文案由
/// presentation 按错误码映射 l10n，内部细节只入日志。
final class UpdateCheckProvider
    extends $NotifierProvider<UpdateCheck, AsyncValue<UpdateState>> {
  /// 更新检查与下载用例：拉取清单、与本地版本比较、下载并校验 APK。
  ///
  /// 错误在此捕获并转成类型化状态（[UpdateErrorCode]），用户可读文案由
  /// presentation 按错误码映射 l10n，内部细节只入日志。
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

String _$updateCheckHash() => r'308f364cc196767ac1cb6b7e7642c8ec624424ce';

/// 更新检查与下载用例：拉取清单、与本地版本比较、下载并校验 APK。
///
/// 错误在此捕获并转成类型化状态（[UpdateErrorCode]），用户可读文案由
/// presentation 按错误码映射 l10n，内部细节只入日志。

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
