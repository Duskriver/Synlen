import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

import '../helpers/book_progress.dart';

/// 当前无已发布用户：旧开发库明确要求重置，新安装直接创建 Locator 结构。
void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('synlen-schema-');
    file = File('${directory.path}/database.sqlite');
  });
  tearDown(() async => directory.delete(recursive: true));

  for (final version in [1, 2]) {
    test('v$version 开发库明确拒绝升级且不改写原始数据', () async {
      final old = sqlite.sqlite3.open(file.path);
      old.execute('CREATE TABLE development_marker (value TEXT)');
      old.execute("INSERT INTO development_marker VALUES ('原有数据')");
      old.execute('PRAGMA user_version = $version');
      old.close();
      final db = AppDatabase.forTesting(NativeDatabase(file));
      await expectLater(
        db.select(db.shelfBooks).get(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            '重置提示',
            contains('重置开发数据库'),
          ),
        ),
      );
      await db.close();
      final untouched = sqlite.sqlite3.open(file.path);
      expect(
        untouched.select('PRAGMA user_version').single['user_version'],
        version,
      );
      expect(
        untouched
            .select('SELECT value FROM development_marker')
            .single['value'],
        '原有数据',
      );
      untouched.close();
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
