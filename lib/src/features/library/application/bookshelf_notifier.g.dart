// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing bookshelf operations with dependency injection

@ProviderFor(BookshelfNotifier)
final bookshelfProvider = BookshelfNotifierProvider._();

/// Notifier for managing bookshelf operations with dependency injection
final class BookshelfNotifierProvider
    extends $AsyncNotifierProvider<BookshelfNotifier, BookshelfState> {
  /// Notifier for managing bookshelf operations with dependency injection
  BookshelfNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookshelfProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookshelfNotifierHash();

  @$internal
  @override
  BookshelfNotifier create() => BookshelfNotifier();
}

String _$bookshelfNotifierHash() => r'03a239653f41ad5b1e4f0e291240c08a2b9f565f';

/// Notifier for managing bookshelf operations with dependency injection

abstract class _$BookshelfNotifier extends $AsyncNotifier<BookshelfState> {
  FutureOr<BookshelfState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BookshelfState>, BookshelfState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BookshelfState>, BookshelfState>,
              AsyncValue<BookshelfState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
