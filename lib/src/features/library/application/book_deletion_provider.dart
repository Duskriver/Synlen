import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/library_book_store_provider.dart';
import '../data/services/book_file_store_provider.dart';
import 'book_deletion.dart';

part 'book_deletion_provider.g.dart';

@riverpod
BookDeletion bookDeletion(Ref ref) {
  final files = ref.watch(bookFileStoreProvider);
  return BookDeletion(
    store: ref.watch(libraryBookStoreProvider),
    removeFiles: (book) =>
        files.removeFiles([book.filePath, book.coverPath].whereType<String>()),
  );
}
