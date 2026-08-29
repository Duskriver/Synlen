import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

/// v1 → v2 迁移测试：v2 为 ShelfBooks / BookManifests 增加 format 列。
///
/// 测试先用原生 SQL 按 v1 结构建库并写入存量数据（user_version = 1），
/// 再用 AppDatabase 打开触发迁移，验证：
/// 1. 存量行补上的 format 默认值为 EPUB；
/// 2. 迁移后能正常读写 TXT 格式。
void main() {
  /// v1 的 shelf_books 建表语句（无 format 列）
  const v1ShelfBooksDdl = '''
    CREATE TABLE shelf_books (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_hash TEXT NOT NULL UNIQUE,
      file_path TEXT,
      cover_path TEXT,
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      authors TEXT NOT NULL DEFAULT '[]',
      description TEXT,
      subjects TEXT NOT NULL DEFAULT '[]',
      total_chapters INTEGER NOT NULL DEFAULT 0,
      epub_version TEXT NOT NULL DEFAULT '',
      import_date INTEGER NOT NULL,
      direction INTEGER NOT NULL DEFAULT 0,
      current_chapter_index INTEGER NOT NULL DEFAULT 0,
      reading_progress REAL NOT NULL DEFAULT 0.0,
      chapter_scroll_position REAL DEFAULT 0.0,
      last_opened_date INTEGER,
      is_finished INTEGER NOT NULL DEFAULT 0,
      group_name TEXT,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      last_synced_date INTEGER
    )
  ''';

  /// v1 的 book_manifests 建表语句（无 format 列）
  const v1BookManifestsDdl = '''
    CREATE TABLE book_manifests (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      file_hash TEXT NOT NULL UNIQUE,
      opf_root_path TEXT NOT NULL,
      spine TEXT NOT NULL,
      toc TEXT NOT NULL,
      manifest TEXT NOT NULL,
      epub_version TEXT NOT NULL,
      last_updated INTEGER NOT NULL
    )
  ''';

  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('synlen_migration_test_');
    dbFile = File('${tempDir.path}/migrate.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 以 v1 结构建库并写入一行存量书籍与清单
  void createV1Database() {
    final sqlite = sqlite3.sqlite3.open(dbFile.path);
    try {
      sqlite.execute(v1ShelfBooksDdl);
      sqlite.execute(v1BookManifestsDdl);
      sqlite.execute(
        "INSERT INTO shelf_books (file_hash, title, author, import_date, updated_at)"
        " VALUES ('old-hash', '旧版书', '旧作者', 1000, 1000)",
      );
      sqlite.execute(
        "INSERT INTO book_manifests (file_hash, opf_root_path, spine, toc, manifest, epub_version, last_updated)"
        " VALUES ('old-hash', 'OEBPS/', '[]', '[]', '[]', '3.0', 1000)",
      );
      sqlite.execute('PRAGMA user_version = 1');
    } finally {
      sqlite.close();
    }
  }

  test('v1 库存量数据迁移后 format 默认为 epub', () async {
    createV1Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    final books = await db.select(db.shelfBooks).get();
    expect(books.single.title, '旧版书');
    expect(books.single.format, BookFormat.epub);

    final manifests = await db.select(db.bookManifests).get();
    expect(manifests.single.fileHash, 'old-hash');
    expect(manifests.single.format, BookFormat.epub);
  });

  test('迁移后 schema 版本升为 2', () async {
    createV1Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    // 触发一次查询以完成打开与迁移
    await db.select(db.shelfBooks).get();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data['user_version'], 2);
  });

  test('迁移后可写入并读回 txt 格式', () async {
    createV1Database();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db
        .into(db.shelfBooks)
        .insert(
          ShelfBooksCompanion.insert(
            fileHash: 'txt-hash',
            title: 'TXT 书',
            author: '',
            importDate: 2000,
            updatedAt: 2000,
            format: const Value(BookFormat.txt),
          ),
        );
    await db
        .into(db.bookManifests)
        .insert(
          BookManifestsCompanion.insert(
            fileHash: 'txt-hash',
            opfRootPath: '',
            spine: const <SpineItem>[],
            toc: const <TocItem>[],
            manifest: const <ManifestItem>[],
            epubVersion: '',
            format: const Value(BookFormat.txt),
            lastUpdated: DateTime.fromMillisecondsSinceEpoch(2000),
          ),
        );

    final book = await (db.select(
      db.shelfBooks,
    )..where((t) => t.fileHash.equals('txt-hash'))).getSingle();
    expect(book.format, BookFormat.txt);

    final manifest = await (db.select(
      db.bookManifests,
    )..where((t) => t.fileHash.equals('txt-hash'))).getSingle();
    expect(manifest.format, BookFormat.txt);
  });

  test('全新建库直接落在 v2 且 format 可用', () async {
    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db
        .into(db.shelfBooks)
        .insert(
          ShelfBooksCompanion.insert(
            fileHash: 'new-hash',
            title: '新书',
            author: '',
            importDate: 3000,
            updatedAt: 3000,
          ),
        );

    final book = await db.select(db.shelfBooks).get();
    expect(book.single.format, BookFormat.epub);

    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data['user_version'], 2);
  });
}
