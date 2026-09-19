// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_file_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookFileStore)
final bookFileStoreProvider = BookFileStoreProvider._();

final class BookFileStoreProvider
    extends $FunctionalProvider<BookFileStore, BookFileStore, BookFileStore>
    with $Provider<BookFileStore> {
  BookFileStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookFileStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookFileStoreHash();

  @$internal
  @override
  $ProviderElement<BookFileStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookFileStore create(Ref ref) {
    return bookFileStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookFileStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookFileStore>(value),
    );
  }
}

String _$bookFileStoreHash() => r'7a0679bdef07d81e9011ce1234fb5b4ac7b1de2e';
