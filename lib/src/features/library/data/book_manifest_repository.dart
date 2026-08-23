import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';

/// BookManifest CRUD 仓库（drift 实现）。
/// 重查询只在打开阅读器时进行。
class BookManifestRepository {
  final AppDatabase _db;

  BookManifestRepository({required AppDatabase db}) : _db = db;

  /// 按文件哈希获取清单（打开书时的主查询）
  Future<BookManifest?> getManifestByHash(String fileHash) async {
    return (_db.select(
      _db.bookManifests,
    )..where((t) => t.fileHash.equals(fileHash))).getSingleOrNull();
  }

  /// 保存或更新清单
  Future<Either<String, int>> saveManifest(BookManifest manifest) async {
    try {
      final id = await _db
          .into(_db.bookManifests)
          .insertOnConflictUpdate(manifest);
      return right(id);
    } catch (e) {
      return left('Save manifest failed: $e');
    }
  }

  /// 按文件哈希删除清单
  Future<Either<String, bool>> deleteManifestByHash(String fileHash) async {
    try {
      final manifest = await getManifestByHash(fileHash);
      if (manifest == null) return right(false);
      final count = await (_db.delete(
        _db.bookManifests,
      )..where((t) => t.id.equals(manifest.id))).go();
      return right(count > 0);
    } catch (e) {
      return left('Delete manifest failed: $e');
    }
  }
}
