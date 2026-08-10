import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/database/providers.dart';
import '../book_manifest_repository.dart';

part 'book_manifest_repository_provider.g.dart';

/// 提供 [BookManifestRepository] 实例
@riverpod
BookManifestRepository bookManifestRepository(
  Ref ref,
) {
  final db = ref.watch(appDatabaseProvider);
  return BookManifestRepository(db: db);
}
