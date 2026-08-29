import 'package:drift/native.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

/// 回归测试：新书入库时 id=0 必须交给数据库自增。
///
/// 此前 saveBook/saveManifest 直接 `insertOnConflictUpdate(dataClass)`，
/// data class 的 id=0 被当作显式主键写入 rowid 0；下一本新书的 upsert
/// 命中同一 rowid，把上一本书整行覆盖（书 A 从书架上消失，只剩书 B）。
void main() {
  late AppDatabase db;
  late ShelfBookRepository shelfRepo;
  late BookManifestRepository manifestRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shelfRepo = ShelfBookRepository(db: db);
    manifestRepo = BookManifestRepository(db: db);
  });

  tearDown(() async => db.close());

  T unwrap<T>(Either<String, T> result) =>
      result.fold((l) => throw StateError(l), identity);

  ShelfBook buildBook(String hash, String title) => ShelfBook(
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
    isDeleted: false,
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

  test('连续保存两本 id=0 的书各自成行，互不覆盖', () async {
    final idA = unwrap(await shelfRepo.saveBook(buildBook('hash-A', '书A')));
    final idB = unwrap(await shelfRepo.saveBook(buildBook('hash-B', '书B')));

    expect(idA, isNot(0));
    expect(idB, isNot(0));
    expect(idA, isNot(idB));

    final rows = await db.select(db.shelfBooks).get();
    expect(rows, hasLength(2));
    expect(
      rows.map((r) => r.title).toSet(),
      equals({'书A', '书B'}),
      reason: '第二本书的 upsert 不得覆盖第一本',
    );
  });

  test('带已有 id 保存时仍按主键更新（恢复/更新场景语义不变）', () async {
    final idA = unwrap(await shelfRepo.saveBook(buildBook('hash-A', '书A')));

    final updated = buildBook('hash-A', '书A-改名').copyWith(id: idA);
    final idAgain = unwrap(await shelfRepo.saveBook(updated));

    expect(idAgain, idA);
    final rows = await db.select(db.shelfBooks).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, '书A-改名');
  });

  test('连续保存两份 id=0 的清单各自成行，互不覆盖', () async {
    final idA = unwrap(
      await manifestRepo.saveManifest(buildManifest('hash-A')),
    );
    final idB = unwrap(
      await manifestRepo.saveManifest(buildManifest('hash-B')),
    );

    expect(idA, isNot(0));
    expect(idB, isNot(0));
    expect(idA, isNot(idB));

    final rows = await db.select(db.bookManifests).get();
    expect(rows, hasLength(2));
    expect(rows.map((r) => r.fileHash).toSet(), equals({'hash-A', 'hash-B'}));
  });
}
