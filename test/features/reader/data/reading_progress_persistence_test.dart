import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/reader/application/reading_progress_controller.dart';
import 'package:synlen/src/features/reader/data/book_session.dart';

void main() {
  test('防抖期间关闭阅读，重开数据库后恢复最后有效位置', () async {
    final directory = await Directory.systemTemp.createTemp('synlen-progress-');
    final databaseFile = File('${directory.path}/reader.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    T unwrap<T>(Either<String, T> result) =>
        result.fold((error) => throw StateError(error), identity);

    final shelfRepo = ShelfBookRepository(db: db);
    final manifestRepo = BookManifestRepository(db: db);
    unwrap(
      await shelfRepo.saveBook(
        const ShelfBook(
          id: 0,
          fileHash: 'reading-book',
          title: '测试书',
          author: '作者',
          authors: ['作者'],
          subjects: [],
          totalChapters: 2,
          epubVersion: '',
          format: BookFormat.txt,
          importDate: 1,
          direction: 0,
          currentChapterIndex: 0,
          readingProgress: 0,
          isFinished: false,
          isDeleted: false,
          updatedAt: 1,
        ),
      ),
    );
    unwrap(
      await manifestRepo.saveManifest(
        BookManifest(
          id: 0,
          fileHash: 'reading-book',
          opfRootPath: '',
          spine: [
            SpineItem(index: 0, href: 'txt/chapter_0.xhtml'),
            SpineItem(index: 1, href: 'txt/chapter_1.xhtml'),
          ],
          toc: [],
          manifest: [],
          epubVersion: '',
          format: BookFormat.txt,
          lastUpdated: DateTime(2026),
        ),
      ),
    );
    final session = BookSession(
      fileHash: 'reading-book',
      shelfBookRepository: shelfRepo,
      manifestRepository: manifestRepo,
    );
    expect(await session.loadBook(), isTrue);
    final controller = ReadingProgressController(
      save: session.saveProgress,
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record((
      chapterIndex: 1,
      pageIndex: 3,
      pageCount: 8,
    ), isReady: true);
    controller.record((
      chapterIndex: 0,
      pageIndex: 0,
      pageCount: 1,
    ), isReady: false);
    expect(await controller.close(), isTrue);
    await db.close();

    db = AppDatabase.forTesting(NativeDatabase(databaseFile));
    final reopened = BookSession(
      fileHash: 'reading-book',
      shelfBookRepository: ShelfBookRepository(db: db),
      manifestRepository: BookManifestRepository(db: db),
    );
    expect(await reopened.loadBook(), isTrue);
    expect(reopened.initialChapterIndex, 1);
    expect(reopened.initialScrollPosition, 3 / 8);
    expect(reopened.book!.readingProgress, 0.75);
    expect(reopened.book!.lastOpenedDate, greaterThan(1));
  });
}
