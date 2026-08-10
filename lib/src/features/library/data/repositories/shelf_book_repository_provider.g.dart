// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shelf_book_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供 [ShelfBookRepository] 实例

@ProviderFor(shelfBookRepository)
final shelfBookRepositoryProvider = ShelfBookRepositoryProvider._();

/// 提供 [ShelfBookRepository] 实例

final class ShelfBookRepositoryProvider
    extends
        $FunctionalProvider<
          ShelfBookRepository,
          ShelfBookRepository,
          ShelfBookRepository
        >
    with $Provider<ShelfBookRepository> {
  /// 提供 [ShelfBookRepository] 实例
  ShelfBookRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shelfBookRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shelfBookRepositoryHash();

  @$internal
  @override
  $ProviderElement<ShelfBookRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShelfBookRepository create(Ref ref) {
    return shelfBookRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShelfBookRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShelfBookRepository>(value),
    );
  }
}

String _$shelfBookRepositoryHash() =>
    r'243ed6cff83834df362a34c5ee45f0a5a23ce51c';
