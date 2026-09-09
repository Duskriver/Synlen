import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';

/// 书架的跨表写编排（drift 实现）。
///
/// ShelfBook 与 BookManifest 靠相同 fileHash 关联（数据库层无外键），
/// 双写必须原子完成；启动一致性修复同样走这里，与导入共用同一事务通道。
class LibraryBookStore {
  final AppDatabase _db;

  LibraryBookStore({required AppDatabase db}) : _db = db;

  /// 在同一事务中保存书与清单，返回书的数据库 ID。
  ///
  /// 任一步失败整个事务回滚，两表都不留记录。id 为 0 的新记录主键必须
  /// 缺席交给自增，与两个仓库的 save 同理。
  Future<Either<String, int>> saveBookWithManifest(
    ShelfBook book,
    BookManifest manifest,
  ) async {
    try {
      return await _db.transaction(() async {
        final bookCompanion = book.id == 0
            ? book.toCompanion(false).copyWith(id: const Value.absent())
            : book.toCompanion(false);
        final bookId = await _db
            .into(_db.shelfBooks)
            .insertOnConflictUpdate(bookCompanion);

        final manifestCompanion = manifest.id == 0
            ? manifest.toCompanion(false).copyWith(id: const Value.absent())
            : manifest.toCompanion(false);
        await _db
            .into(_db.bookManifests)
            .insertOnConflictUpdate(manifestCompanion);

        return right(bookId);
      });
    } catch (e) {
      return left('Save book with manifest failed: $e');
    }
  }

  /// 启动一致性修复：清理两个方向的 DB 孤儿，返回（删书数, 删清单数）。
  ///
  /// - 无清单的未删除书：旧版导入第二步失败的残留，无法打开阅读，硬删除。
  ///   软删除的墓碑行不动：备份恢复与同步语义依赖它。
  /// - 无书的清单：任何路径都不可达的纯垃圾，删除。
  ///
  /// 只在启动时跑一次，此时不可能有导入在进行；扫描与删除在同一事务中
  /// 完成。被删书的物理文件交由 StorageCleanupService 清理。
  Future<Either<String, (int, int)>> repairOrphanRecords() async {
    try {
      return await _db.transaction(() async {
        final books = await _db.select(_db.shelfBooks).get();
        final manifests = await _db.select(_db.bookManifests).get();
        final bookHashes = books.map((b) => b.fileHash).toSet();
        final manifestHashes = manifests.map((m) => m.fileHash).toSet();

        var removedBooks = 0;
        for (final book in books) {
          if (!book.isDeleted && !manifestHashes.contains(book.fileHash)) {
            removedBooks += await (_db.delete(
              _db.shelfBooks,
            )..where((t) => t.id.equals(book.id))).go();
          }
        }

        var removedManifests = 0;
        for (final manifest in manifests) {
          if (!bookHashes.contains(manifest.fileHash)) {
            removedManifests += await (_db.delete(
              _db.bookManifests,
            )..where((t) => t.id.equals(manifest.id))).go();
          }
        }

        return right((removedBooks, removedManifests));
      });
    } catch (e) {
      return left('Repair orphan records failed: $e');
    }
  }
}
