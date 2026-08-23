import 'package:synlen/src/features/library/data/repositories/book_manifest_repository_provider.dart';
import 'package:synlen/src/features/library/data/repositories/shelf_book_repository_provider.dart';
import 'package:synlen/src/features/library/data/services/unified_import_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'import_backup_service.dart';

part 'import_backup_service_provider.g.dart';

/// Provider for [ImportBackupService].
///
/// 直接注入数据库实例，以便服务调用 repository 层未暴露的
/// 按索引 upsert 方法（`putByFileHash`、`putByName`）。
@riverpod
ImportBackupService importBackupService(Ref ref) {
  final shelfBookRepo = ref.watch(shelfBookRepositoryProvider);
  final manifestRepo = ref.watch(bookManifestRepositoryProvider);

  final importService = ref.watch(unifiedImportServiceProvider);
  return ImportBackupService(
    shelfBookRepository: shelfBookRepo,
    bookManifestRepository: manifestRepo,
    importService: importService,
  );
}
