import 'package:drift/drift.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/shelf_book_sort_by.dart';
import 'package:collection/collection.dart';

/// ShelfBook CRUD 仓库（drift 实现）。
/// 轻量查询供 UI 展示与同步使用；业务规则（分组/删除/排序）已上移，
/// 本层只做纯存取。
class ShelfBookRepository {
  final AppDatabase _db;

  ShelfBookRepository({required AppDatabase db}) : _db = db;

  /// 获取所有未删除的书，按导入时间倒序
  Future<List<ShelfBook>> getAllBooks() async {
    final query = _db.select(_db.shelfBooks)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.importDate)]);
    return query.get();
  }

  /// 获取所有未删除书的文件哈希集合。
  /// 供 [StorageCleanupService] 判断物理文件是否有效。
  Future<Set<String>> getAllNotDeletedFileHashes() async {
    final books = await (_db.select(
      _db.shelfBooks,
    )..where((t) => t.isDeleted.equals(false))).get();
    return books.map((b) => b.fileHash).toSet();
  }

  /// 获取书列表，支持高级排序与可选分组过滤
  Future<List<ShelfBook>> getBooksSorted({
    ShelfBookSortBy sortBy = ShelfBookSortBy.recentlyAdded,
    String? groupName,
    bool includeAll = false,
  }) async {
    final query = _db.select(_db.shelfBooks)
      ..where((t) {
        var condition = t.isDeleted.equals(false);
        if (!includeAll) {
          condition = groupName != null
              ? condition & t.groupName.equals(groupName)
              : condition & t.groupName.isNull();
        }
        return condition;
      });

    // 数据库排序：最近阅读 / 最近添加 / 进度
    switch (sortBy) {
      case ShelfBookSortBy.recentlyRead:
        query.orderBy([(t) => OrderingTerm.desc(t.lastOpenedDate)]);
        return query.get();
      case ShelfBookSortBy.recentlyAdded:
        query.orderBy([(t) => OrderingTerm.desc(t.importDate)]);
        return query.get();
      case ShelfBookSortBy.progress:
        query.orderBy([(t) => OrderingTerm.desc(t.readingProgress)]);
        return query.get();
      case ShelfBookSortBy.titleAsc:
      case ShelfBookSortBy.titleDesc:
      case ShelfBookSortBy.authorAsc:
      case ShelfBookSortBy.authorDesc:
        break;
    }

    // 标题/作者使用自然排序（大小写不敏感、数字感知）
    final books = await query.get();
    switch (sortBy) {
      case ShelfBookSortBy.titleAsc:
        return books..sort((a, b) => compareNatural(a.title, b.title));
      case ShelfBookSortBy.titleDesc:
        return books..sort((a, b) => compareNatural(b.title, a.title));
      case ShelfBookSortBy.authorAsc:
        return books..sort((a, b) => compareNatural(a.author, b.author));
      case ShelfBookSortBy.authorDesc:
        return books..sort((a, b) => compareNatural(b.author, a.author));
      default:
        return books;
    }
  }

  /// 获取所有未删除的分组（扁平结构，按名称排序）
  Future<List<ShelfGroup>> getGroups() async {
    final query = _db.select(_db.shelfGroups)
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  /// 按 ID 获取分组
  Future<ShelfGroup?> getGroupById(int id) async {
    return (_db.select(
      _db.shelfGroups,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按名称获取分组（未删除）
  Future<ShelfGroup?> getGroupByName(String name) async {
    return (_db.select(_db.shelfGroups)
          ..where((t) => t.name.equals(name) & t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  /// 保存分组（插入或更新）
  Future<ShelfGroup> saveGroup(ShelfGroup group) async {
    await _db.into(_db.shelfGroups).insertOnConflictUpdate(group);
    return group;
  }

  /// 创建新分组；已存在同名分组时撤销删除并返回其 id
  Future<Either<String, int>> createGroup({required String name}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final existingGroup = await (_db.select(
        _db.shelfGroups,
      )..where((t) => t.name.equals(name))).getSingleOrNull();

      if (existingGroup != null) {
        if (existingGroup.isDeleted) {
          // 分组被软删除：恢复它
          await (_db.update(
            _db.shelfGroups,
          )..where((t) => t.id.equals(existingGroup.id))).write(
            ShelfGroupsCompanion(
              isDeleted: const Value(false),
              updatedAt: Value(now),
            ),
          );
          return right(existingGroup.id);
        }
        return left('Group already exists');
      }

      final id = await _db
          .into(_db.shelfGroups)
          .insert(
            ShelfGroupsCompanion.insert(
              name: name,
              creationDate: now,
              updatedAt: now,
            ),
          );
      return right(id);
    } catch (e) {
      return left('Create group failed: $e');
    }
  }

  /// 重命名分组，并同步更新其下所有书的分组名
  Future<Either<String, bool>> updateGroupName({
    required int groupId,
    required String name,
  }) async {
    try {
      return await _db.transaction(() async {
        final group = await getGroupById(groupId);
        if (group == null) {
          return left('Group not found');
        }
        final oldGroupName = group.name;
        await (_db.update(
          _db.shelfGroups,
        )..where((t) => t.id.equals(groupId))).write(
          ShelfGroupsCompanion(
            name: Value(name),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );

        await (_db.update(
          _db.shelfBooks,
        )..where((t) => t.groupName.equals(oldGroupName))).write(
          ShelfBooksCompanion(
            groupName: Value(name),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        return right(true);
      });
    } catch (e) {
      return left('Update group failed: $e');
    }
  }

  /// 删除分组并解除其下所有书的归属
  Future<Either<String, bool>> deleteGroup({required int groupId}) async {
    try {
      return await _db.transaction(() async {
        final group = await getGroupById(groupId);
        if (group == null) {
          return left('Group not found');
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        // 解除书的归属
        await (_db.update(
          _db.shelfBooks,
        )..where((t) => t.groupName.equals(group.name))).write(
          ShelfBooksCompanion(
            groupName: const Value(null),
            updatedAt: Value(now),
          ),
        );
        // 软删除分组
        await (_db.update(
          _db.shelfGroups,
        )..where((t) => t.id.equals(groupId))).write(
          ShelfGroupsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ),
        );
        return right(true);
      });
    } catch (e) {
      return left('Delete group failed: $e');
    }
  }

  /// 更新单本书的分组归属
  Future<Either<String, bool>> updateBookGroup({
    required int bookId,
    String? groupName,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.shelfBooks,
      )..where((t) => t.id.equals(bookId))).write(
        ShelfBooksCompanion(groupName: Value(groupName), updatedAt: Value(now)),
      );
      return right(true);
    } catch (e) {
      return left('Update group failed: $e');
    }
  }

  /// 批量移动多本书到指定分组
  Future<Either<String, bool>> moveBooksToGroup({
    required Set<int> bookIds,
    String? targetGroupName,
  }) async {
    try {
      if (bookIds.isEmpty) return right(true);
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.shelfBooks,
      )..where((t) => t.id.isIn(bookIds))).write(
        ShelfBooksCompanion(
          groupName: Value(targetGroupName),
          updatedAt: Value(now),
        ),
      );
      return right(true);
    } catch (e) {
      return left('Move books failed: $e');
    }
  }

  /// 软删除一本书
  Future<Either<String, bool>> softDeleteBook(int bookId) async {
    try {
      await (_db.update(
        _db.shelfBooks,
      )..where((t) => t.id.equals(bookId))).write(
        ShelfBooksCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      return right(true);
    } catch (e) {
      return left('Soft delete failed: $e');
    }
  }

  /// 按 ID 获取书
  Future<ShelfBook?> getBookById(int id) async {
    return (_db.select(
      _db.shelfBooks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 按文件哈希获取书
  Future<ShelfBook?> getBookByHash(String fileHash) async {
    return (_db.select(
      _db.shelfBooks,
    )..where((t) => t.fileHash.equals(fileHash))).getSingleOrNull();
  }

  /// 按哈希检查书是否存在
  Future<bool> bookExists(String fileHash) async {
    final book = await getBookByHash(fileHash);
    return book != null;
  }

  /// 按哈希检查书是否存在且未删除
  Future<bool> bookExistsAndNotDeleted(String fileHash) async {
    final book = await getBookByHash(fileHash);
    return book != null && !book.isDeleted;
  }

  /// 按哈希获取书 ID；不存在则抛异常
  Future<int> getBookIdByHash(String fileHash) async {
    final book = await getBookByHash(fileHash);
    if (book != null) {
      return book.id;
    }
    throw Exception('Book not found for hash: $fileHash');
  }

  /// 保存或更新一本书，返回其 ID。
  ///
  /// id 为 0 表示新书：主键必须缺席交给 SQLite 自增。若把 0 当显式主键
  /// 插入（rowid 0），下一本新书的 upsert 会命中同一 rowid 并把上一本
  /// 书的整行覆盖掉。
  Future<Either<String, int>> saveBook(ShelfBook book) async {
    try {
      final companion = book.id == 0
          ? book.toCompanion(false).copyWith(id: const Value.absent())
          : book.toCompanion(false);
      final id = await _db
          .into(_db.shelfBooks)
          .insertOnConflictUpdate(companion);
      return right(id);
    } catch (e) {
      return left('Save failed: $e');
    }
  }

  /// 按 ID 永久删除一本书
  Future<Either<String, bool>> deleteBook(int id) async {
    try {
      final count = await (_db.delete(
        _db.shelfBooks,
      )..where((t) => t.id.equals(id))).go();
      return right(count > 0);
    } catch (e) {
      return left('Delete failed: $e');
    }
  }

  /// 更新阅读进度
  Future<Either<String, bool>> updateProgress({
    required int bookId,
    required int currentChapterIndex,
    required double progress,
    required double? scrollPosition,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final count =
          await (_db.update(
            _db.shelfBooks,
          )..where((t) => t.id.equals(bookId))).write(
            ShelfBooksCompanion(
              currentChapterIndex: Value(currentChapterIndex),
              readingProgress: Value(progress),
              chapterScrollPosition: Value(scrollPosition),
              lastOpenedDate: Value(now),
            ),
          );
      return right(count > 0);
    } catch (e) {
      return left('Update progress failed: $e');
    }
  }
}
