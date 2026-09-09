// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_actions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 单本书的读取、元数据保存与文件分享用例。
///
/// 保存与分享都按 fileHash 现取整行：调用方只提供编辑后的字段，
/// 不持有 drift 行类型。

@ProviderFor(BookActions)
final bookActionsProvider = BookActionsProvider._();

/// 单本书的读取、元数据保存与文件分享用例。
///
/// 保存与分享都按 fileHash 现取整行：调用方只提供编辑后的字段，
/// 不持有 drift 行类型。
final class BookActionsProvider extends $NotifierProvider<BookActions, void> {
  /// 单本书的读取、元数据保存与文件分享用例。
  ///
  /// 保存与分享都按 fileHash 现取整行：调用方只提供编辑后的字段，
  /// 不持有 drift 行类型。
  BookActionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookActionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookActionsHash();

  @$internal
  @override
  BookActions create() => BookActions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$bookActionsHash() => r'3435153c885d6cba628d2fdb401741a7ad61f8a9';

/// 单本书的读取、元数据保存与文件分享用例。
///
/// 保存与分享都按 fileHash 现取整行：调用方只提供编辑后的字段，
/// 不持有 drift 行类型。

abstract class _$BookActions extends $Notifier<void> {
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
