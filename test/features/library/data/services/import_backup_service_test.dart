import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/application/progress_log.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/services/import_backup_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';

/// 本地文件替代平台读取；书籍仍经过真实缓存复制与哈希计算。
class LocalBackupImport extends UnifiedImportService {
  LocalBackupImport() : super(cacheManager: ImportCacheManager());
  int releases = 0;

  @override
  Future<Uint8List> processBinaryFile(PlatformPath path) =>
      File((path as IOSFilePath).path).readAsBytes();

  @override
  Future<void> releaseIosAccess() async => releases++;
}

void main() {
  late Directory root;
  late AppDatabase db;
  late ShelfBookRepository shelfRepo;
  late BookManifestRepository manifestRepo;
  late LocalBackupImport fileImport;
  late ImportBackupService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-restore-');
    AppStorage.initForTesting(
      documentsPath: '${root.path}/documents',
      tempPath: '${root.path}/cache',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shelfRepo = ShelfBookRepository(db: db);
    manifestRepo = BookManifestRepository(db: db);
    fileImport = LocalBackupImport();
    service = ImportBackupService(
      shelfBookRepository: shelfRepo,
      bookManifestRepository: manifestRepo,
      importService: fileImport,
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  T unwrap<T>(Either<String, T> result) =>
      result.fold((error) => throw StateError(error), (value) => value);

  Map<String, dynamic> bookMap({
    String hash = 'book-a',
    String title = '备份标题',
    int updatedAt = 200,
    int? readAt = 200,
    String? format = 'txt',
  }) => {
    'fileHash': hash,
    'title': title,
    'author': '备份作者',
    'authors': ['备份作者'],
    'subjects': ['英语'],
    'description': '备份介绍',
    'totalChapters': 2,
    'epubVersion': '',
    'format': ?format,
    'importDate': 10,
    'currentChapterIndex': 0,
    'readingProgress': 0.2,
    'chapterScrollPosition': 0.3,
    'lastOpenedDate': readAt,
    'isFinished': false,
    'groupName': '书组',
    'isDeleted': false,
    'updatedAt': updatedAt,
    'direction': 0,
  };

  Map<String, dynamic> manifestMap({
    String hash = 'book-a',
    // 数据库的 dateTime 列按秒存储，测试时间戳保持整秒避免精度损失。
    int updatedAt = 2000,
    String? format = 'txt',
  }) => {
    'version': 1,
    'fileHash': hash,
    'opfRootPath': '',
    'epubVersion': '',
    'format': ?format,
    'lastUpdated': DateTime.fromMillisecondsSinceEpoch(
      updatedAt,
    ).toIso8601String(),
    'spine': [
      {
        'index': 0,
        'href': 'txt/chapter_0.xhtml',
        'idref': '0',
        'sourceRange': '0-4',
      },
      {
        'index': 1,
        'href': 'txt/chapter_1.xhtml',
        'idref': '1',
        'sourceRange': '4-8',
      },
    ],
    'toc': [],
    'manifest': [],
  };

  Future<BackupPaths> backup({
    List<Map<String, dynamic>>? books,
    Map<String, Map<String, dynamic>>? manifests,
    bool withCover = false,
  }) async {
    final items = books ?? [bookMap()];
    final directory = await Directory('${root.path}/backup').create();
    final shelf = File('${directory.path}/shelf.json');
    await shelf.writeAsString(
      jsonEncode({
        'version': 1,
        'books': items,
        'groups': [
          {'name': '书组', 'creationDate': 10, 'updatedAt': 20},
        ],
      }),
    );
    final paths = <String, BackupPathsForBook>{};
    for (final item in items) {
      final hash = item['fileHash'] as String;
      final extension = item['format'] == 'txt' ? 'txt' : 'epub';
      final bookFile = File('${directory.path}/$hash.$extension');
      await bookFile.writeAsString('one\ntwo\n');
      final manifest = File('${directory.path}/$hash.json');
      await manifest.writeAsString(
        jsonEncode(manifests?[hash] ?? manifestMap(hash: hash)),
      );
      final cover = File('${directory.path}/$hash.jpg');
      if (withCover) await cover.writeAsBytes([1, 2, 3]);
      paths[hash] = BackupPathsForBook(
        epubPath: IOSFilePath(bookFile.path),
        manifestPath: IOSFilePath(manifest.path),
        coverPath: withCover ? IOSFilePath(cover.path) : null,
      );
    }
    return BackupPaths(
      rootPath: IOSFilePath(directory.path),
      shelfFile: IOSFilePath(shelf.path),
      bookPaths: paths,
    );
  }

  Future<ShelfBook> localBook({
    int updatedAt = 100,
    int? readAt = 300,
    bool isDeleted = false,
    String? coverPath,
  }) async {
    final book = ShelfBook(
      id: 0,
      fileHash: 'book-a',
      title: '本机标题',
      author: '本机作者',
      authors: const ['本机作者'],
      subjects: const ['小说'],
      description: '本机介绍',
      totalChapters: 2,
      epubVersion: '',
      format: BookFormat.txt,
      importDate: 1,
      direction: 0,
      currentChapterIndex: 1,
      readingProgress: 0.8,
      chapterScrollPosition: 0.6,
      lastOpenedDate: readAt,
      isFinished: true,
      isDeleted: isDeleted,
      updatedAt: updatedAt,
      coverPath: coverPath,
    );
    final id = unwrap(await shelfRepo.saveBook(book));
    return book.copyWith(id: id);
  }

  Future<List<BackupImportProgress>> restore(BackupPaths paths) async =>
      (await service.importLibraryFromFolder(paths).toList())
          .whereType<BackupImportProgress>()
          .toList();

  test('空库恢复、重复恢复、更新清单均保持同一记录且备份文件不被删除', () async {
    final paths = await backup(
      books: [
        bookMap(),
        bookMap(hash: 'book-b'),
      ],
    );
    expect((await restore(paths)).last.result, isA<ImportSuccess>());
    final firstBook = (await shelfRepo.getBookByHash('book-a'))!;
    final firstManifest = (await manifestRepo.getManifestByHash('book-a'))!;
    final firstGroup = (await shelfRepo.getGroups()).single;
    expect(firstGroup.creationDate, 10);
    expect(firstGroup.updatedAt, 20);
    expect((await restore(paths)).last.result, isA<ImportSuccess>());
    final newer = manifestMap(updatedAt: 4000)..['opfRootPath'] = 'new-root/';
    await File(
      (paths.bookPaths['book-a']!.manifestPath as IOSFilePath).path,
    ).writeAsString(jsonEncode(newer));
    expect((await restore(paths)).last.result, isA<ImportSuccess>());
    expect(await db.select(db.shelfBooks).get(), hasLength(2));
    expect(await db.select(db.bookManifests).get(), hasLength(2));
    expect(await db.select(db.shelfGroups).get(), hasLength(1));
    final result = (await manifestRepo.getManifestByHash('book-a'))!;
    expect(result.id, firstManifest.id);
    expect(result.opfRootPath, 'new-root/');
    expect((await shelfRepo.getBookByHash('book-a'))!.id, firstBook.id);
    expect(await File((paths.shelfFile as IOSFilePath).path).exists(), isTrue);
    expect(
      await File('${AppStorage.documentsPath}books/book-a.txt').readAsString(),
      'one\ntwo\n',
    );
    expect(fileImport.releases, 3);
  });

  test('已有清单更新失败保留原值，不计为恢复成功', () async {
    final paths = await backup();
    await restore(paths);
    final original = (await manifestRepo.getManifestByHash('book-a'))!;
    await db.customStatement(
      "CREATE TRIGGER reject_manifest_update BEFORE UPDATE ON book_manifests "
      "BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await File(
      (paths.bookPaths['book-a']!.manifestPath as IOSFilePath).path,
    ).writeAsString(jsonEncode(manifestMap(updatedAt: 9000)));
    final progress = await restore(paths);
    expect(progress.last.result, isA<ImportFailure>());
    expect(progress.last.current, 0);
    final result = (await manifestRepo.getManifestByHash('book-a'))!;
    expect(result.id, original.id);
    expect(result.lastUpdated, original.lastUpdated);
  });

  test('较旧清单不覆盖本机较新版本', () async {
    final paths = await backup(
      manifests: {'book-a': manifestMap(updatedAt: 2000)},
    );
    await restore(paths);
    await File(
      (paths.bookPaths['book-a']!.manifestPath as IOSFilePath).path,
    ).writeAsString(jsonEncode(manifestMap(updatedAt: 1000)));
    expect((await restore(paths)).last.result, isA<ImportSuccess>());
    expect(
      (await manifestRepo.getManifestByHash('book-a'))!.lastUpdated,
      DateTime.fromMillisecondsSinceEpoch(2000),
    );
  });

  test('元数据与进度同时更新时只提交一次最终书目，空章内位置可覆盖旧值', () async {
    await localBook(updatedAt: 100, readAt: 100);
    await db.customStatement('CREATE TABLE write_count (book_id INTEGER)');
    await db.customStatement(
      'CREATE TRIGGER count_book_update AFTER UPDATE ON shelf_books '
      'BEGIN INSERT INTO write_count VALUES (NEW.id); END',
    );
    final data = bookMap()..['chapterScrollPosition'] = null;
    expect(
      (await restore(await backup(books: [data]))).last.result,
      isA<ImportSuccess>(),
    );
    expect(
      await db.customSelect('SELECT * FROM write_count').get(),
      hasLength(1),
    );
    expect(
      (await shelfRepo.getBookByHash('book-a'))!.chapterScrollPosition,
      isNull,
    );
  });

  test('旧版无格式字段的备份按 EPUB 恢复', () async {
    final paths = await backup(
      books: [bookMap(format: null)],
      manifests: {'book-a': manifestMap(format: null)},
    );
    expect((await restore(paths)).last.result, isA<ImportSuccess>());
    expect((await shelfRepo.getBookByHash('book-a'))!.format, BookFormat.epub);
    expect(
      (await manifestRepo.getManifestByHash('book-a'))!.format,
      BookFormat.epub,
    );
    expect(
      await File('${AppStorage.documentsPath}books/book-a.epub').exists(),
      isTrue,
    );
  });

  for (final scenario in [
    (
      name: '备份元数据新、本机进度新',
      localMeta: 100,
      backupMeta: 200,
      localRead: 300,
      backupRead: 200,
      backupProgress: false,
    ),
    (
      name: '本机元数据新、备份进度新',
      localMeta: 300,
      backupMeta: 200,
      localRead: 100,
      backupRead: 200,
      backupProgress: true,
    ),
    (
      name: '备份元数据与进度都新',
      localMeta: 100,
      backupMeta: 200,
      localRead: 100,
      backupRead: 200,
      backupProgress: true,
    ),
    (
      name: '时间相同保留本机',
      localMeta: 200,
      backupMeta: 200,
      localRead: 200,
      backupRead: 200,
      backupProgress: false,
    ),
    (
      name: '本机未读、备份已读',
      localMeta: 100,
      backupMeta: 200,
      localRead: null,
      backupRead: 200,
      backupProgress: true,
    ),
    (
      name: '备份未读、本机已读',
      localMeta: 100,
      backupMeta: 200,
      localRead: 300,
      backupRead: null,
      backupProgress: false,
    ),
    (
      name: '都无阅读时间保留本机位置',
      localMeta: 100,
      backupMeta: 200,
      localRead: null,
      backupRead: null,
      backupProgress: false,
    ),
  ]) {
    test('元数据与进度独立合并：${scenario.name}', () async {
      final local = await localBook(
        updatedAt: scenario.localMeta,
        readAt: scenario.localRead,
      );
      final paths = await backup(
        books: [
          bookMap(updatedAt: scenario.backupMeta, readAt: scenario.backupRead),
        ],
      );
      expect((await restore(paths)).last.result, isA<ImportSuccess>());
      final result = (await shelfRepo.getBookByHash('book-a'))!;
      expect(result.id, local.id);
      expect(
        result.title,
        scenario.backupMeta > scenario.localMeta ? '备份标题' : '本机标题',
      );
      expect(
        result.updatedAt,
        scenario.backupMeta > scenario.localMeta
            ? scenario.backupMeta
            : scenario.localMeta,
      );
      expect(result.currentChapterIndex, scenario.backupProgress ? 0 : 1);
      expect(result.readingProgress, scenario.backupProgress ? 0.2 : 0.8);
      expect(result.chapterScrollPosition, scenario.backupProgress ? 0.3 : 0.6);
      expect(result.isFinished, !scenario.backupProgress);
      expect(
        result.lastOpenedDate,
        scenario.backupProgress ? scenario.backupRead : scenario.localRead,
      );
    });
  }

  test('恢复已软删除的书仍保留本机较新的元数据和进度', () async {
    await localBook(updatedAt: 400, readAt: 500, isDeleted: true);
    expect((await restore(await backup())).last.result, isA<ImportSuccess>());
    final result = (await shelfRepo.getBookByHash('book-a'))!;
    expect(result.isDeleted, isFalse);
    expect(result.title, '本机标题');
    expect(result.readingProgress, 0.8);
    expect(result.lastOpenedDate, 500);
  });

  test('较旧备份不能覆盖本机较新元数据所用的封面文件', () async {
    await localBook(updatedAt: 400, coverPath: 'covers/book-a.jpg');
    final cover = File('${AppStorage.documentsPath}covers/book-a.jpg');
    await cover.parent.create(recursive: true);
    await cover.writeAsBytes([8, 9]);
    expect(
      (await restore(await backup(withCover: true))).last.result,
      isA<ImportSuccess>(),
    );
    expect(await cover.readAsBytes(), [8, 9]);
    expect(
      (await shelfRepo.getBookByHash('book-a'))!.coverPath,
      'covers/book-a.jpg',
    );
  });

  for (final table in ['book_manifests', 'shelf_books', 'shelf_groups']) {
    test('$table 写入失败不得计为成功，且释放平台访问', () async {
      await db.customStatement(
        'CREATE TRIGGER reject_write BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT, \'test failure\'); END',
      );
      final paths = await backup();
      final logs = await service.importLibraryFromFolder(paths).toList();
      final progress = logs.whereType<BackupImportProgress>().toList();
      expect(progress.last.result, isA<ImportFailure>());
      expect(progress.last.current, 0);
      expect(progress.last.total, 1);
      expect(progress.where((event) => event.result is ImportSuccess), isEmpty);
      expect(
        logs.where((event) => event.type == ProgressLogType.success),
        isEmpty,
      );
      expect(fileImport.releases, 1);
    });
  }

  test('第二本缺文件时保留第一本成功数，并报告未完整恢复', () async {
    final paths = await backup(
      books: [
        bookMap(),
        bookMap(hash: 'book-b'),
      ],
    );
    paths.bookPaths.remove('book-b');
    final progress = await restore(paths);
    expect(progress.last.result, isA<ImportFailure>());
    expect(progress.last.current, 1);
    expect(progress.last.total, 2);
    expect(await shelfRepo.getAllBooks(), hasLength(1));
  });

  test('书架与清单的书籍标识不一致时拒绝入库', () async {
    final paths = await backup(
      manifests: {'book-a': manifestMap(hash: 'other')},
    );
    expect((await restore(paths)).last.result, isA<ImportFailure>());
    expect(await db.select(db.shelfBooks).get(), isEmpty);
    expect(await db.select(db.bookManifests).get(), isEmpty);
  });
}
