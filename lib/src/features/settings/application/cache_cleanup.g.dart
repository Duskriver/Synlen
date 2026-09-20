// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache_cleanup.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 页面订阅用例，用例订阅服务；退出后不再启动后续清理阶段。

@ProviderFor(CacheCleanup)
final cacheCleanupProvider = CacheCleanupProvider._();

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 页面订阅用例，用例订阅服务；退出后不再启动后续清理阶段。
final class CacheCleanupProvider
    extends $NotifierProvider<CacheCleanup, AsyncValue<int?>> {
  /// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
  /// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
  ///
  /// 页面订阅用例，用例订阅服务；退出后不再启动后续清理阶段。
  CacheCleanupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheCleanupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheCleanupHash();

  @$internal
  @override
  CacheCleanup create() => CacheCleanup();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<int?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<int?>>(value),
    );
  }
}

String _$cacheCleanupHash() => r'da47ce95492573f841778f9b3e347acea5bf2d94';

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 页面订阅用例，用例订阅服务；退出后不再启动后续清理阶段。

abstract class _$CacheCleanup extends $Notifier<AsyncValue<int?>> {
  AsyncValue<int?> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int?>, AsyncValue<int?>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int?>, AsyncValue<int?>>,
              AsyncValue<int?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
