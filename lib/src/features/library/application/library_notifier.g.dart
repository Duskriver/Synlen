// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。

@ProviderFor(LibraryNotifier)
final libraryProvider = LibraryNotifierProvider._();

/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。
final class LibraryNotifierProvider
    extends $NotifierProvider<LibraryNotifier, void> {
  /// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
  /// 这里不持有任何状态。
  LibraryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryNotifierHash();

  @$internal
  @override
  LibraryNotifier create() => LibraryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$libraryNotifierHash() => r'a34274bad25324475441d17cbd32614fa6dc55b8';

/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。

abstract class _$LibraryNotifier extends $Notifier<void> {
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
