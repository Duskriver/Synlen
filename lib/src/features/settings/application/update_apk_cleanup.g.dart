// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_apk_cleanup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Android 启动时回收安装包；失败保留记录供下次启动重试，不阻断使用。

@ProviderFor(updateApkCleanup)
final updateApkCleanupProvider = UpdateApkCleanupProvider._();

/// Android 启动时回收安装包；失败保留记录供下次启动重试，不阻断使用。

final class UpdateApkCleanupProvider
    extends $FunctionalProvider<AsyncValue<bool>, bool, FutureOr<bool>>
    with $FutureModifier<bool>, $FutureProvider<bool> {
  /// Android 启动时回收安装包；失败保留记录供下次启动重试，不阻断使用。
  UpdateApkCleanupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'updateApkCleanupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$updateApkCleanupHash();

  @$internal
  @override
  $FutureProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<bool> create(Ref ref) {
    return updateApkCleanup(ref);
  }
}

String _$updateApkCleanupHash() => r'e5418405dee7a253bca6ad23952f45ed0f4b7cfd';
