// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_deletion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(bookDeletion)
final bookDeletionProvider = BookDeletionProvider._();

final class BookDeletionProvider
    extends $FunctionalProvider<BookDeletion, BookDeletion, BookDeletion>
    with $Provider<BookDeletion> {
  BookDeletionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookDeletionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookDeletionHash();

  @$internal
  @override
  $ProviderElement<BookDeletion> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookDeletion create(Ref ref) {
    return bookDeletion(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookDeletion value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookDeletion>(value),
    );
  }
}

String _$bookDeletionHash() => r'1d2ba709c14a8a4a968672e0e2d01cf693717932';
