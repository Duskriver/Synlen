import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';

import '../data/library_book_store.dart';
import '../data/library_book_store_provider.dart';

part 'library_consistency_repair.g.dart';

/// 启动时的一次性书架一致性修复。
///
/// 清理两个方向的 DB 孤儿（见 [LibraryBookStore.repairOrphanRecords]）。
/// fire-and-forget：失败只记日志，不阻塞首屏。
@riverpod
Future<void> libraryConsistencyRepair(Ref ref) async {
  final result = await ref
      .watch(libraryBookStoreProvider)
      .repairOrphanRecords();
  result.fold((error) => appLogger.e('书架一致性修复失败：$error'), (counts) {
    final (books, manifests) = counts;
    if (books + manifests > 0) {
      appLogger.i('书架一致性修复：清理无清单的书 $books 本、无书的清单 $manifests 份');
    }
  });
}
