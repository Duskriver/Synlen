import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../library_book_store_provider.dart';
import '../repositories/shelf_book_repository_provider.dart';
import '../repositories/book_manifest_repository_provider.dart';
import 'book_import_service.dart';

part 'book_import_service_provider.g.dart';

/// Provider for BookImportService
/// This service handles EPUB file import, parsing, and storage
@riverpod
BookImportService bookImportService(Ref ref) {
  final shelfBookRepo = ref.watch(shelfBookRepositoryProvider);
  final manifestRepo = ref.watch(bookManifestRepositoryProvider);
  final libraryBookStore = ref.watch(libraryBookStoreProvider);

  return BookImportService(
    shelfBookRepo: shelfBookRepo,
    manifestRepo: manifestRepo,
    libraryBookStore: libraryBookStore,
  );
}
