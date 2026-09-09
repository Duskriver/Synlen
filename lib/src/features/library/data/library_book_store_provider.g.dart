// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_book_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供 [LibraryBookStore] 实例

@ProviderFor(libraryBookStore)
final libraryBookStoreProvider = LibraryBookStoreProvider._();

/// 提供 [LibraryBookStore] 实例

final class LibraryBookStoreProvider
    extends
        $FunctionalProvider<
          LibraryBookStore,
          LibraryBookStore,
          LibraryBookStore
        >
    with $Provider<LibraryBookStore> {
  /// 提供 [LibraryBookStore] 实例
  LibraryBookStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryBookStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryBookStoreHash();

  @$internal
  @override
  $ProviderElement<LibraryBookStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LibraryBookStore create(Ref ref) {
    return libraryBookStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryBookStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryBookStore>(value),
    );
  }
}

String _$libraryBookStoreHash() => r'1a0b751a8e2c087dbaaa614349d25ea3ebc5d453';
