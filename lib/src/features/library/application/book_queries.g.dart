// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_queries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 供 reader 等宿主读取书目与提交进度的入口。

@ProviderFor(bookQueries)
final bookQueriesProvider = BookQueriesProvider._();

/// 供 reader 等宿主读取书目与提交进度的入口。

final class BookQueriesProvider
    extends $FunctionalProvider<BookQueries, BookQueries, BookQueries>
    with $Provider<BookQueries> {
  /// 供 reader 等宿主读取书目与提交进度的入口。
  BookQueriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookQueriesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookQueriesHash();

  @$internal
  @override
  $ProviderElement<BookQueries> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookQueries create(Ref ref) {
    return bookQueries(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookQueries value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookQueries>(value),
    );
  }
}

String _$bookQueriesHash() => r'4545b8aae502fdb6b515f7c86ed71011cc21fd95';
