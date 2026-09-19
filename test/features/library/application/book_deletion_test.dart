import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/features/library/application/bookshelf_notifier.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'package:synlen/src/features/library/data/services/book_file_store_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/book_deletion.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

class _LockedFiles extends BookFileStore {
  @override
  Future<void> removeFiles(Iterable<String> paths) async =>
      throw StateError('文件被占用');
}

void main() {
  late AppDatabase db;
  late LibraryBookStore store;
  late ShelfBook book;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = LibraryBookStore(db: db);
    final row = ShelfBook(
      id: 0,
      fileHash: 'hash',
      title: '书',
      author: '',
      authors: const [],
      subjects: const [],
      totalChapters: 1,
      epubVersion: '',
      format: BookFormat.txt,
      importDate: 1,
      updatedAt: 1,
      direction: 0,
      currentChapterIndex: 0,
      readingProgress: 0,
      isFinished: false,
      isDeleted: false,
    );
    final result = await store.saveBookWithManifest(
      row,
      BookManifest(
        id: 0,
        fileHash: 'hash',
        opfRootPath: '',
        spine: const [],
        toc: const [],
        manifest: const [],
        epubVersion: '',
        format: BookFormat.txt,
        lastUpdated: DateTime(2026),
      ),
    );
    book = row.copyWith(id: result.getRight().toNullable()!);
  });
  tearDown(() => db.close());

  test('清单删除失败回滚墓碑，且不触碰文件', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_delete BEFORE DELETE ON book_manifests BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    var touched = false;
    final deletion = BookDeletion(
      store: store,
      removeFiles: (_) async => touched = true,
    );
    expect(await deletion.delete(book), BookDeletionResult.failed);
    expect((await db.select(db.shelfBooks).get()).single.isDeleted, isFalse);
    expect(await db.select(db.bookManifests).get(), hasLength(1));
    expect(touched, isFalse);
  });

  test('文件清理失败保留已提交墓碑，重试可完成清理', () async {
    var fail = true;
    final deletion = BookDeletion(
      store: store,
      removeFiles: (_) async {
        expect((await db.select(db.shelfBooks).get()).single.isDeleted, isTrue);
        expect(await db.select(db.bookManifests).get(), isEmpty);
        if (fail) throw StateError('文件被占用');
      },
    );
    expect(await deletion.delete(book), BookDeletionResult.cleanupPending);
    fail = false;
    expect(await deletion.delete(book), BookDeletionResult.deleted);
    expect((await db.select(db.shelfBooks).get()).single.fileHash, 'hash');
  });
  test('书架删除入口在文件暂不可删时仍刷新列表并清空选择', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        bookFileStoreProvider.overrideWithValue(_LockedFiles()),
      ],
    );
    final subscription = container.listen(bookshelfProvider, (_, _) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
    });
    await container.read(bookshelfProvider.future);
    final notifier = container.read(bookshelfProvider.notifier);
    notifier.toggleSelectionMode();
    notifier.toggleItemSelection(book.id);
    expect(await notifier.deleteSelected(), isTrue);
    final state = await container.read(bookshelfProvider.future);
    expect(state.books, isEmpty);
    expect(state.hasSelection, isFalse);
    expect((await db.select(db.shelfBooks).get()).single.isDeleted, isTrue);
  });
}
