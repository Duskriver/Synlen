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
/// 跨 feature 编排只允许出现在组合面（ADR-0003）。

@ProviderFor(CacheCleanup)
final cacheCleanupProvider = CacheCleanupProvider._();

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 跨 feature 编排只允许出现在组合面（ADR-0003）。
final class CacheCleanupProvider extends $NotifierProvider<CacheCleanup, void> {
  /// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
  /// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
  ///
  /// 跨 feature 编排只允许出现在组合面（ADR-0003）。
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
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$cacheCleanupHash() => r'b62a777d48c7e1b7d9cff7db2982756c30a502d2';

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 跨 feature 编排只允许出现在组合面（ADR-0003）。

abstract class _$CacheCleanup extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
