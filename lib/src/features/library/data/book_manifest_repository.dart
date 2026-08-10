import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

/// BookManifest CRUD 仓库（drift 实现）。
/// 重查询只在打开阅读器时进行。
class BookManifestRepository {
  final AppDatabase _db;

  BookManifestRepository({required AppDatabase db}) : _db = db;

  /// 按文件哈希获取清单（打开书时的主查询）
  Future<BookManifest?> getManifestByHash(String fileHash) async {
    return (_db.select(_db.bookManifests)
          ..where((t) => t.fileHash.equals(fileHash)))
        .getSingleOrNull();
  }

  /// 按 ID 获取清单
  Future<BookManifest?> getManifestById(int id) async {
    return (_db.select(_db.bookManifests)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 按哈希检查清单是否存在
  Future<bool> manifestExists(String fileHash) async {
    final manifest = await getManifestByHash(fileHash);
    return manifest != null;
  }

  /// 保存或更新清单
  Future<Either<String, int>> saveManifest(BookManifest manifest) async {
    try {
      final id = await _db.into(_db.bookManifests).insertOnConflictUpdate(manifest);
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
      final count = await (_db.delete(_db.bookManifests)
            ..where((t) => t.id.equals(manifest.id)))
          .go();
      return right(count > 0);
    } catch (e) {
      return left('Delete manifest failed: $e');
    }
  }

  /// 按 ID 删除清单
  Future<Either<String, bool>> deleteManifest(int id) async {
    try {
      final count = await (_db.delete(_db.bookManifests)
            ..where((t) => t.id.equals(id)))
          .go();
      return right(count > 0);
    } catch (e) {
      return left('Delete manifest failed: $e');
    }
  }

  /// 获取全部清单（很少使用，主要供调试/迁移）
  Future<List<BookManifest>> getAllManifests() async {
    return _db.select(_db.bookManifests).get();
  }

  /// 按索引获取脊项（避免为简单导航加载完整清单）
  Future<SpineItem?> getSpineItemByIndex(String fileHash, int index) async {
    final manifest = await getManifestByHash(fileHash);
    if (manifest != null && index >= 0 && index < manifest.spine.length) {
      return manifest.spine[index];
    }
    return null;
  }

  /// 获取脊项总数
  Future<int?> getSpineCount(String fileHash) async {
    final manifest = await getManifestByHash(fileHash);
    return manifest?.spine.length;
  }

  /// 展平目录为简单列表（供 UI 展示）
  Future<List<TocItem>> getFlattenedToc(String fileHash) async {
    final manifest = await getManifestByHash(fileHash);
    if (manifest == null) return [];

    return _flattenTocItems(manifest.toc);
  }

  /// 递归展平目录
  List<TocItem> _flattenTocItems(List<TocItem> items) {
    final result = <TocItem>[];
    for (final item in items) {
      result.add(item);
      if (item.children.isNotEmpty) {
        result.addAll(_flattenTocItems(item.children));
      }
    }
    return result;
  }
}
