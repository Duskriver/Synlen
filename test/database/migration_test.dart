import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

import '../helpers/book_progress.dart';

/// 真实旧结构升级保留所有行；失败时连同 DDL 和版本号一起回滚。
void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('synlen-schema-');
    file = File('${directory.path}/database.sqlite');
  });
  tearDown(() async => directory.delete(recursive: true));

  const unchangedTables = [
    'shelf_groups',
    'word_explanations',
    'word_pronunciations',
    'sentence_analyses',
    'sentence_pronunciations',
  ];
  void seed(int version, {bool corrupt = false}) {
    final old = sqlite.sqlite3.open(file.path);
    old.execute(File('test/fixtures/database_v1.sql').readAsStringSync());
    if (version == 2) {
      for (final table in ['shelf_books', 'book_manifests']) {
        old.execute(
          "ALTER TABLE $table ADD COLUMN format TEXT NOT NULL DEFAULT 'epub'",
        );
      }
    }
    for (var i = 1; i <= 2; i++) {
      old.execute(
        "INSERT INTO shelf_books (id, file_hash, file_path, cover_path, title, author, "
        "authors, description, subjects, total_chapters, epub_version, import_date, "
        "direction, current_chapter_index, reading_progress, chapter_scroll_position, "
        "last_opened_date, is_finished, group_name, is_deleted, updated_at, last_synced_date) "
        "VALUES (?, ?, ?, ?, '旧书', '作者', '[\"作者\"]', '简介', '[\"文学\"]', 5, '3.0', "
        "100, 1, ?, .64, ?, 200, 1, '书组', ?, 300, 400)",
        [
          i,
          'book-$i',
          'books/book-$i.epub',
          'covers/book-$i.png',
          corrupt && i == 2 ? 'broken' : 3,
          i == 1 ? .2 : null,
          i == 1 ? 0 : 1,
        ],
      );
      old.execute(
        "INSERT INTO book_manifests VALUES (?, ?, 'OEBPS/', '[]', '[]', '[]', '3.0', 100${version == 2 ? ", 'epub'" : ''})",
        [i, 'book-$i'],
      );
    }
    if (version == 2) {
      old.execute(
        "UPDATE shelf_books SET format = 'txt', file_path = 'books/book-2.txt' WHERE id = 2",
      );
      old.execute("UPDATE book_manifests SET format = 'txt' WHERE id = 2");
    }
    old.execute("INSERT INTO shelf_groups VALUES (7, '书组', 10, 20, 0)");
    old.execute(
      "INSERT INTO word_explanations VALUES (8, 'word', '释义', 30, '上下文')",
    );
    old.execute(
      "INSERT INTO word_pronunciations VALUES (9, 'word', 'audio/word.mp3', 40)",
    );
    old.execute(
      "INSERT INTO sentence_analyses VALUES (10, 'sentence', '分析', 50)",
    );
    old.execute(
      "INSERT INTO sentence_pronunciations VALUES (11, 'sentence', 'audio/sentence.mp3', 60)",
    );
    old.execute('PRAGMA user_version = $version');
    old.close();
  }

  for (final version in [1, 2]) {
    test('schema $version 升级保留书目、旧坐标、清单、分组与学习缓存，重开不重迁', () async {
      seed(version);
      final old = sqlite.sqlite3.open(file.path);
      final previousBooks = old
          .select('SELECT * FROM shelf_books ORDER BY id')
          .map((row) => Map<String, Object?>.from(row))
          .toList();
      final previousTables = {
        for (final table in unchangedTables)
          table: old
              .select('SELECT * FROM $table')
              .map((row) => Map<String, Object?>.from(row))
              .toList(),
      };
      old.close();
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final books = await db.select(db.shelfBooks).get();
      expect(books, hasLength(2));
      for (final book in books) {
        expect(book.progress!.legacy, (
          chapterIndex: 3,
          progression: book.id == 1 ? .2 : null,
        ));
        expect(book.progress!.locator, isNull);
        expect(book.progress!.fraction, .64);
      }
      final migrated = await db
          .customSelect('SELECT * FROM shelf_books ORDER BY id')
          .get();
      for (var i = 0; i < migrated.length; i++) {
        final before = previousBooks[i]
          ..remove('current_chapter_index')
          ..remove('chapter_scroll_position');
        before.putIfAbsent('format', () => 'epub');
        final after = Map<String, Object?>.from(migrated[i].data)
          ..remove('progress');
        expect(after, before);
      }
      for (final table in unchangedTables) {
        expect(
          (await db.customSelect('SELECT * FROM $table').get())
              .map((row) => row.data)
              .toList(),
          previousTables[table],
        );
      }
      final manifests = await db.select(db.bookManifests).get();
      expect(manifests.map((m) => m.fileHash), ['book-1', 'book-2']);
      expect(
        manifests.last.format,
        version == 2 ? BookFormat.txt : BookFormat.epub,
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data['user_version'],
        3,
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      expect(
        (await db.select(db.shelfBooks).get())
            .map((book) => book.toJson())
            .toList(),
        books.map((book) => book.toJson()).toList(),
      );
      await (db.update(db.shelfBooks)..where((t) => t.id.equals(1))).write(
        ShelfBooksCompanion(progress: Value(testBookProgress())),
      );
      expect(
        (await db.select(db.shelfBooks).get()).first.progress,
        testBookProgress(),
      );
    });

    test('schema $version 迁移中途失败时回滚旧行、列和版本', () async {
      seed(version, corrupt: true);
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(db.select(db.shelfBooks).get(), throwsA(anything));
      await db.close();
      final old = sqlite.sqlite3.open(file.path);
      expect(old.select('PRAGMA user_version').single['user_version'], version);
      final columns = old
          .select('PRAGMA table_info(shelf_books)')
          .map((row) => row['name'])
          .toList();
      expect(columns, isNot(contains('progress')));
      expect(columns.contains('format'), version == 2);
      expect(
        old
            .select('SELECT current_chapter_index FROM shelf_books ORDER BY id')
            .map((r) => r['current_chapter_index']),
        [3, 'broken'],
      );
      old.close();
    });
  }

  test('新库直接创建 schema 3，EPUB/TXT 与完整 Locator 可往返', () async {
    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    for (final format in BookFormat.values) {
      await db
          .into(db.shelfBooks)
          .insert(
            ShelfBooksCompanion.insert(
              fileHash: format.name,
              title: '新书',
              author: '',
              importDate: 1,
              updatedAt: 1,
              format: Value(format),
              progress: Value(testBookProgress()),
              readingProgress: const Value(0.5),
            ),
          );
    }
    final books = await db.select(db.shelfBooks).get();
    expect(books.map((book) => book.format).toSet(), BookFormat.values.toSet());
    expect(books.every((book) => book.progress == testBookProgress()), isTrue);
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      3,
    );
  });
}
