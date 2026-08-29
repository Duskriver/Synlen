// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。
///
/// 必须 keepAlive：`importPipelineStream` / `importLibraryFromFolder` 是
/// async* 函数，方法体推迟到 UI 对话框监听流之后才执行；若为 autoDispose，
/// 调用方只做 `read`（无监听），provider 会在流开始运行前被销毁，方法体内的
/// `ref.read` 随之抛出 "Cannot use the Ref ... after it has been disposed"。

@ProviderFor(LibraryNotifier)
final libraryProvider = LibraryNotifierProvider._();

/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。
///
/// 必须 keepAlive：`importPipelineStream` / `importLibraryFromFolder` 是
/// async* 函数，方法体推迟到 UI 对话框监听流之后才执行；若为 autoDispose，
/// 调用方只做 `read`（无监听），provider 会在流开始运行前被销毁，方法体内的
/// `ref.read` 随之抛出 "Cannot use the Ref ... after it has been disposed"。
final class LibraryNotifierProvider
    extends $NotifierProvider<LibraryNotifier, void> {
  /// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
  /// 这里不持有任何状态。
  ///
  /// 必须 keepAlive：`importPipelineStream` / `importLibraryFromFolder` 是
  /// async* 函数，方法体推迟到 UI 对话框监听流之后才执行；若为 autoDispose，
  /// 调用方只做 `read`（无监听），provider 会在流开始运行前被销毁，方法体内的
  /// `ref.read` 随之抛出 "Cannot use the Ref ... after it has been disposed"。
  LibraryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryProvider',
        isAutoDispose: false,
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

String _$libraryNotifierHash() => r'7d4554c390256ad50261aca990aaa73a144e75bf';

/// 导入编排 Notifier:仅承载导入/删除流程,书架数据源是 bookshelfProvider,
/// 这里不持有任何状态。
///
/// 必须 keepAlive：`importPipelineStream` / `importLibraryFromFolder` 是
/// async* 函数，方法体推迟到 UI 对话框监听流之后才执行；若为 autoDispose，
/// 调用方只做 `read`（无监听），provider 会在流开始运行前被销毁，方法体内的
/// `ref.read` 随之抛出 "Cannot use the Ref ... after it has been disposed"。

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
