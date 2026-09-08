// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_import_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for BookImportService
/// This service handles EPUB file import, parsing, and storage

@ProviderFor(bookImportService)
final bookImportServiceProvider = BookImportServiceProvider._();

/// Provider for BookImportService
/// This service handles EPUB file import, parsing, and storage

final class BookImportServiceProvider
    extends
        $FunctionalProvider<
          BookImportService,
          BookImportService,
          BookImportService
        >
    with $Provider<BookImportService> {
  /// Provider for BookImportService
  /// This service handles EPUB file import, parsing, and storage
  BookImportServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookImportServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookImportServiceHash();

  @$internal
  @override
  $ProviderElement<BookImportService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BookImportService create(Ref ref) {
    return bookImportService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookImportService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookImportService>(value),
    );
  }
}

String _$bookImportServiceHash() => r'674f75ebebc7facb53a2f64648d40e72d55a1b9e';
