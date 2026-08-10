import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/database/providers.dart';
import '../shelf_book_repository.dart';

part 'shelf_book_repository_provider.g.dart';

/// 提供 [ShelfBookRepository] 实例
@riverpod
ShelfBookRepository shelfBookRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ShelfBookRepository(db: db);
}
