import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

/// LibraryBookStore 测试：导入双写的事务性，与启动一致性修复的删除规则。
void main() {
  late AppDatabase db;
  late LibraryBookStore store;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = LibraryBookStore(db: db);
  });

  tearDown(() async => db.close());

  T unwrap<T>(Either<String, T> result) =>
      result.fold((l) => throw StateError(l), identity);

  ShelfBook buildBook(String hash, String title, {bool isDeleted = false}) =>
      ShelfBook(
        id: 0,
        fileHash: hash,
        title: title,
        author: '作者',
        authors: const ['作者'],
        subjects: const [],
        totalChapters: 1,
        epubVersion: '',
        format: BookFormat.txt,
        importDate: 1,
        direction: 0,
        currentChapterIndex: 0,
        readingProgress: 0,
        isFinished: false,
        isDeleted: isDeleted,
        updatedAt: 1,
      );

  BookManifest buildManifest(String hash) => BookManifest(
    id: 0,
    fileHash: hash,
    opfRootPath: '',
    spine: const [],
    toc: const [],
    manifest: const [],
    epubVersion: '',
    format: BookFormat.txt,
    lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
  );

  Future<List<String>> bookHashes() async =>
      (await db.select(db.shelfBooks).get()).map((b) => b.fileHash).toList();

  Future<List<String>> manifestHashes() async =>
      (await db.select(db.bookManifests).get()).map((m) => m.fileHash).toList();

  /// 绕过双写直接插入书行，构造孤儿数据；id 缺席交给自增
  Future<void> insertBookRow(ShelfBook book) => db
      .into(db.shelfBooks)
      .insert(book.toCompanion(false).copyWith(id: const Value.absent()));

  /// 同上，直接插入清单行
  Future<void> insertManifestRow(BookManifest manifest) => db
      .into(db.bookManifests)
      .insert(manifest.toCompanion(false).copyWith(id: const Value.absent()));

  group('saveBookWithManifest', () {
    test('双写成功：书与清单同时落库，返回书的自增 ID', () async {
      final bookId = unwrap(
        await store.saveBookWithManifest(
          buildBook('hash-A', '书A'),
          buildManifest('hash-A'),
        ),
      );

      expect(bookId, isNot(0));
      expect(await bookHashes(), ['hash-A']);
      expect(await manifestHashes(), ['hash-A']);
    });

    test('清单写入抛错时事务回滚：两表都不留记录', () async {
      // 触发建库后拆掉清单表，让事务的第二步写入必然失败
      await db.select(db.bookManifests).get();
      await db.customStatement('DROP TABLE book_manifests');

      final result = await store.saveBookWithManifest(
        buildBook('hash-B', '书B'),
        buildManifest('hash-B'),
      );

      expect(result.isLeft(), isTrue);
      expect(await bookHashes(), isEmpty, reason: '书的写入必须随事务回滚');
    });
  });

  group('repairOrphanRecords', () {
    test('清理无清单的未删除书，软删除的墓碑行保留', () async {
      unwrap(
        await store.saveBookWithManifest(
          buildBook('healthy', '健康书'),
          buildManifest('healthy'),
        ),
      );
      // 孤儿书：旧版导入第二步失败的残留，绕过双写直接插入
      await insertBookRow(buildBook('orphan', '孤儿书'));
      await insertBookRow(buildBook('tombstone', '已删书', isDeleted: true));

      final counts = unwrap(await store.repairOrphanRecords());

      expect(counts, (1, 0));
      expect(await bookHashes(), unorderedEquals(['healthy', 'tombstone']));
      expect(await manifestHashes(), ['healthy']);
    });

    test('清理无书的清单，有书的清单保留', () async {
      unwrap(
        await store.saveBookWithManifest(
          buildBook('healthy', '健康书'),
          buildManifest('healthy'),
        ),
      );
      await insertManifestRow(buildManifest('orphan-manifest'));

      final counts = unwrap(await store.repairOrphanRecords());

      expect(counts, (0, 1));
      expect(await bookHashes(), ['healthy']);
      expect(await manifestHashes(), ['healthy']);
    });

    test('数据健康时不误删，计数为 (0, 0)', () async {
      unwrap(
        await store.saveBookWithManifest(
          buildBook('hash-A', '书A'),
          buildManifest('hash-A'),
        ),
      );
      unwrap(
        await store.saveBookWithManifest(
          buildBook('hash-B', '书B'),
          buildManifest('hash-B'),
        ),
      );

      final counts = unwrap(await store.repairOrphanRecords());

      expect(counts, (0, 0));
      expect(await bookHashes(), unorderedEquals(['hash-A', 'hash-B']));
      expect(await manifestHashes(), unorderedEquals(['hash-A', 'hash-B']));
    });
  });
}
