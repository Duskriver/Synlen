import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/providers.dart';
import 'library_book_store.dart';

part 'library_book_store_provider.g.dart';

/// 提供 [LibraryBookStore] 实例
@riverpod
LibraryBookStore libraryBookStore(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return LibraryBookStore(db: db);
}
