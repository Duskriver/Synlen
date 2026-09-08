import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/application/library_notifier.dart';
import 'package:synlen/src/features/library/domain/import_progress.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service.dart';
import 'package:synlen/src/features/library/data/services/import_backup_service.dart';
import 'package:synlen/src/features/library/data/services/import_backup_service_provider.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late ShelfBookRepository shelfRepo;
  late BookManifestRepository manifestRepo;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-roundtrip-');
    AppStorage.initForTesting(
      documentsPath: '${root.path}/documents',
      tempPath: '${root.path}/cache',
    );
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shelfRepo = ShelfBookRepository(db: db);
    manifestRepo = BookManifestRepository(db: db);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  /// 在 documents 落盘源文件并写入数据库，构成一份可导出的书库。
  Future<void> seedLibrary() async {
    await File(
      '${AppStorage.documentsPath}books/book-a.txt',
    ).create(recursive: true);
    await File(
      '${AppStorage.documentsPath}books/book-a.txt',
    ).writeAsString('one\ntwo\n');
    await File(
      '${AppStorage.documentsPath}covers/book-a.jpg',
    ).create(recursive: true);
    await File(
      '${AppStorage.documentsPath}covers/book-a.jpg',
    ).writeAsBytes([8, 9]);

    await shelfRepo.saveBook(
      ShelfBook(
        id: 0,
        fileHash: 'book-a',
        title: '测试书',
        author: '作者',
        authors: const ['作者'],
        subjects: const ['英语'],
        description: '介绍',
        totalChapters: 2,
        epubVersion: '',
        format: BookFormat.txt,
        importDate: 1,
        direction: 0,
        currentChapterIndex: 1,
        readingProgress: 0.8,
        chapterScrollPosition: 0.6,
        lastOpenedDate: 300,
        isFinished: true,
        isDeleted: false,
        updatedAt: 100,
        coverPath: 'covers/book-a.jpg',
      ),
    );
    await manifestRepo.saveManifest(
      BookManifest(
        id: 0,
        fileHash: 'book-a',
        opfRootPath: '',
        spine: [
          SpineItem(index: 0, href: 'txt/chapter_0.xhtml', sourceRange: '0-4'),
          SpineItem(index: 1, href: 'txt/chapter_1.xhtml', sourceRange: '4-8'),
        ],
        toc: const [],
        manifest: const [],
        epubVersion: '',
        format: BookFormat.txt,
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
    );
    await shelfRepo.createGroup(name: '书组');
  }

  /// 导出并把分享面板收到的 ZIP 复制到稳定位置，返回该副本路径。
  Future<String> exportAndCaptureZip({
    ShareResultStatus status = ShareResultStatus.success,
  }) async {
    String? capturedPath;
    final service = ExportBackupService(
      shelfBookRepo: shelfRepo,
      manifestRepo: manifestRepo,
      share: (params) async {
        final file = params.files!.single;
        capturedPath = '${root.path}/captured-backup.zip';
        await File(file.path).copy(capturedPath!);
        return ShareResult('stub', status);
      },
    );

    final result = await service.exportLibraryAsFile(
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10),
      shareTitle: '书库备份',
    );
    expect(result, isA<ExportSuccess>());
    final zipPath = capturedPath!;
    expect(File(zipPath).existsSync(), isTrue);

    // 备份临时目录在导出结束后不应残留内容。
    final backupTempDir = Directory('${AppStorage.tempPath}backup');
    if (backupTempDir.existsSync()) {
      expect(backupTempDir.listSync(), isEmpty);
    }
    return zipPath;
  }

  test('导出 ZIP 包含 shelf.json、书籍、封面与清单', () async {
    await seedLibrary();
    final zipPath = await exportAndCaptureZip();

    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(['shelf.json', 'books/book-a.txt']));
    expect(names.where((n) => n.startsWith('covers/book-a.')), isNotEmpty);
    expect(names.where((n) => n.startsWith('manifests/book-a.')), isNotEmpty);

    final shelfJson = archive.findFile('shelf.json')!;
    final shelf =
        jsonDecode(utf8.decode(shelfJson.content as List<int>))
            as Map<String, dynamic>;
    expect(shelf['books'], hasLength(1));
    expect((shelf['books'] as List).first['fileHash'], 'book-a');
  });

  test('导出的 ZIP 经解压恢复后完整还原书库，临时解压目录被清理', () async {
    await seedLibrary();
    final zipPath = await exportAndCaptureZip();

    // 新库模拟另一台设备。
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    shelfRepo = ShelfBookRepository(db: db);
    manifestRepo = BookManifestRepository(db: db);

    final unified = UnifiedImportService(cacheManager: ImportCacheManager());
    final paths = await unified.processBackupZip(IOSFilePath(zipPath));
    final extractDir = Directory((paths.rootPath as IOSFilePath).path);

    final container = ProviderContainer(
      overrides: [
        importBackupServiceProvider.overrideWithValue(
          ImportBackupService(
            shelfBookRepository: shelfRepo,
            bookManifestRepository: manifestRepo,
            importService: unified,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    // 通过 LibraryNotifier 的流恢复，验证其负责的解压目录清理。
    final logs = await container
        .read(libraryProvider.notifier)
        .importLibraryFromFolder(paths, cleanupDir: extractDir)
        .toList();
    expect(logs.any((log) => log.type == ProgressLogType.success), isTrue);

    final book = (await shelfRepo.getBookByHash('book-a'))!;
    expect(book.title, '测试书');
    expect(book.readingProgress, 0.8);
    expect(book.currentChapterIndex, 1);
    expect(book.lastOpenedDate, 300);
    expect(book.coverPath, 'covers/book-a.jpg');
    expect(
      await File('${AppStorage.documentsPath}covers/book-a.jpg').readAsBytes(),
      [8, 9],
    );
    expect((await manifestRepo.getManifestByHash('book-a'))!, isNotNull);
    expect((await shelfRepo.getGroups()).single.name, '书组');

    // 恢复流结束后解压目录应不存在。
    expect(extractDir.existsSync(), isFalse);
  });

  test('用户在分享面板取消时报告失败', () async {
    await seedLibrary();
    String? tempZipPath;
    final service = ExportBackupService(
      shelfBookRepo: shelfRepo,
      manifestRepo: manifestRepo,
      share: (params) async {
        tempZipPath = params.files!.single.path;
        return ShareResult('stub', ShareResultStatus.dismissed);
      },
    );

    final result = await service.exportLibraryAsFile(shareTitle: '书库备份');
    expect(result, isA<ExportFailure>());
    // 取消后导出临时文件同样被清理。
    expect(File(tempZipPath!).existsSync(), isFalse);
  });

  test('损坏的 ZIP 抛出异常且不留解压目录', () async {
    final badZip = File('${root.path}/bad.zip');
    await badZip.writeAsBytes([1, 2, 3, 4, 5]);

    final unified = UnifiedImportService(cacheManager: ImportCacheManager());
    await expectLater(
      unified.processBackupZip(IOSFilePath(badZip.path)),
      throwsA(anything),
    );
    final cacheDir = Directory('${AppStorage.tempPath}import_cache');
    expect(
      cacheDir.listSync().whereType<Directory>().where(
        (d) => d.path.contains('backup_extract_'),
      ),
      isEmpty,
    );
  });

  test('缺少 shelf.json 的 ZIP 抛出异常且不留解压目录', () async {
    final dir = Directory('${root.path}/incomplete')..create();
    await File('${dir.path}/books/book-a.txt').create(recursive: true);
    await File('${dir.path}/books/book-a.txt').writeAsString('x');

    final zipPath = '${root.path}/incomplete.zip';
    final encoder = ZipFileEncoder();
    await encoder.zipDirectory(dir, filename: zipPath);

    final unified = UnifiedImportService(cacheManager: ImportCacheManager());
    await expectLater(
      unified.processBackupZip(IOSFilePath(zipPath)),
      throwsA(anything),
    );
    final cacheDir = Directory('${AppStorage.tempPath}import_cache');
    expect(
      cacheDir.listSync().whereType<Directory>().where(
        (d) => d.path.contains('backup_extract_'),
      ),
      isEmpty,
    );
  });
}
