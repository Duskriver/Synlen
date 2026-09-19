import '../library_book_store_provider.dart';
import 'package:synlen/src/features/library/data/repositories/shelf_book_repository_provider.dart';
import 'package:synlen/src/core/providers/unified_import_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'import_backup_service.dart';

part 'import_backup_service_provider.g.dart';

/// 注入恢复所需的书目读取、跨表事务与平台文件入口。
@riverpod
ImportBackupService importBackupService(Ref ref) {
  final shelfBookRepo = ref.watch(shelfBookRepositoryProvider);
  final bookStore = ref.watch(libraryBookStoreProvider);

  final importService = ref.watch(unifiedImportServiceProvider);
  return ImportBackupService(
    shelfBookRepository: shelfBookRepo,
    bookStore: bookStore,
    importService: importService,
  );
}
