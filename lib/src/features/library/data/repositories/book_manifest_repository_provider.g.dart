// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_manifest_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 提供 [BookManifestRepository] 实例

@ProviderFor(bookManifestRepository)
final bookManifestRepositoryProvider = BookManifestRepositoryProvider._();

/// 提供 [BookManifestRepository] 实例

final class BookManifestRepositoryProvider
    extends
        $FunctionalProvider<
          BookManifestRepository,
          BookManifestRepository,
          BookManifestRepository
        >
    with $Provider<BookManifestRepository> {
  /// 提供 [BookManifestRepository] 实例
  BookManifestRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookManifestRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookManifestRepositoryHash();

  @$internal
  @override
  $ProviderElement<BookManifestRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookManifestRepository create(Ref ref) {
    return bookManifestRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookManifestRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookManifestRepository>(value),
    );
  }
}

String _$bookManifestRepositoryHash() =>
    r'c49df9686250153b04bf145d4cc05af3acf92553';
