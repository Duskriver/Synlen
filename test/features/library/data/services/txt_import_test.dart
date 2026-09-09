import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';
import 'package:synlen/src/features/library/data/book_manifest_repository.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

import 'txt_import_test.mocks.dart';

@GenerateMocks([ShelfBookRepository, BookManifestRepository, LibraryBookStore])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockShelfBookRepository shelfRepo;
  late MockBookManifestRepository manifestRepo;
  late MockLibraryBookStore libraryBookStore;
  late BookImportService service;
  late Directory tempDir;
  late Directory booksDir;

  /// 章节文本与导入书名（GBK 用例与嗅探用例共用断言）
  const chapterText = '第一章 闺塾\n春蚕到死丝方尽\n第二章 惜春\n蜡炬成灰泪始干';

  setUp(() async {
    shelfRepo = MockShelfBookRepository();
    manifestRepo = MockBookManifestRepository();
    libraryBookStore = MockLibraryBookStore();
    service = BookImportService(
      shelfBookRepo: shelfRepo,
      manifestRepo: manifestRepo,
      libraryBookStore: libraryBookStore,
    );

    // AppStorage 是静态全局，测试指向独立临时目录，避免触碰真实应用存储
    tempDir = await Directory.systemTemp.createTemp('synlen_txt_import_test_');
    AppStorage.initForTesting(documentsPath: tempDir.path);
    // 与服务端 _writeNormalizedTxt 同一拼法（documentsPath 保证尾斜杠）
    booksDir = Directory(
      '${AppStorage.documentsPath}${AppStorageConstants.booksDir}',
    );

    provideDummy<Either<String, int>>(left('dummy'));
    provideDummy<Either<String, bool>>(left('dummy'));

    when(shelfRepo.bookExistsAndNotDeleted(any)).thenAnswer((_) async => false);
    when(shelfRepo.bookExists(any)).thenAnswer((_) async => false);
    when(
      libraryBookStore.saveBookWithManifest(any, any),
    ).thenAnswer((_) async => right(1));
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  File writeSourceFile(String name, List<int> bytes) {
    final file = File('${tempDir.path}/$name');
    file.writeAsBytesSync(bytes);
    return file;
  }

  /// 捕获双写调用：单次调用同时拿到书与清单
  (ShelfBook, BookManifest) captureSavedPair() {
    final captured = verify(
      libraryBookStore.saveBookWithManifest(captureAny, captureAny),
    ).captured;
    return (captured[0] as ShelfBook, captured[1] as BookManifest);
  }

  group('TXT 导入', () {
    test('GBK 编码 TXT 导入成功：归一化 UTF-8 落盘且实体带 format 与字节范围', () async {
      final source = writeSourceFile('测试书.txt', gbk.encode(chapterText));

      final result = await service.importBook(
        source,
        originalFileName: '测试书.txt',
      );

      expect(
        result.isRight(),
        isTrue,
        reason: result.getLeft().toNullable()?.toString(),
      );
      final book = result.getOrElse((l) => throw l);
      // 返回的 book 与写库实体一致（双写单次捕获）
      final (savedBook, manifest) = captureSavedPair();
      expect(savedBook.title, book.title);

      // 实体：格式、书名取自文件名、章节数
      expect(book.format, BookFormat.txt);
      expect(book.title, '测试书');
      expect(book.totalChapters, 2);
      expect(book.epubVersion, '');

      // 落盘：books/{hash}.txt 为归一化后的合法 UTF-8
      final savedBytes = await File(
        '${booksDir.path}/${book.fileHash}.txt',
      ).readAsBytes();
      expect(utf8.decode(savedBytes), chapterText);
      expect(
        book.filePath,
        '${AppStorageConstants.booksDir}/${book.fileHash}.txt',
      );

      // manifest：spine 字节范围与落盘文件严格对齐
      expect(manifest.format, BookFormat.txt);
      expect(manifest.spine.length, 2);
      var expectedStart = 0;
      for (var i = 0; i < manifest.spine.length; i++) {
        final item = manifest.spine[i];
        expect(item.href, 'txt/chapter_$i.xhtml');
        final parts = item.sourceRange!.split('-');
        final start = int.parse(parts[0]);
        final end = int.parse(parts[1]);
        expect(start, expectedStart);
        expect(
          utf8.decode(savedBytes.sublist(start, end)),
          contains(i == 0 ? '第一章' : '第二章'),
        );
        expectedStart = end;
      }
      expect(expectedStart, savedBytes.length);
    });

    test('扩展名说谎时按内容嗅探纠偏：.epub 名的纯文本按 TXT 导入', () async {
      // 模拟 SAF 数字文档 ID 场景：真实文件名不可得，兜底为 unknown.epub
      final source = writeSourceFile('temp_1.epub', utf8.encode(chapterText));

      final result = await service.importBook(
        source,
        originalFileName: 'unknown.epub',
      );

      expect(
        result.isRight(),
        isTrue,
        reason: result.getLeft().toNullable()?.toString(),
      );
      expect(result.getRight().toNullable()!.format, BookFormat.txt);
    });

    test('TXT 源文件无 BOM 的 UTF-8 编码可直接导入', () async {
      final source = writeSourceFile('plain.txt', utf8.encode(chapterText));

      final result = await service.importBook(
        source,
        originalFileName: 'plain.txt',
      );

      expect(
        result.isRight(),
        isTrue,
        reason: result.getLeft().toNullable()?.toString(),
      );
      expect(result.getRight().toNullable()!.title, 'plain');
    });

    test('二进制伪装 .txt 返回 left 且不落盘、不写库', () async {
      final source = writeSourceFile(
        'fake.txt',
        Uint8List.fromList(List.generate(200, (i) => i.isEven ? 0xFF : 0x01)),
      );

      final result = await service.importBook(
        source,
        originalFileName: 'fake.txt',
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()?.code, LibraryErrorCode.parseFailed);
      expect(booksDir.existsSync(), isFalse);
      verifyNever(libraryBookStore.saveBookWithManifest(any, any));
    });

    test('书籍已存在时返回 left 且不重复导入', () async {
      when(
        shelfRepo.bookExistsAndNotDeleted(any),
      ).thenAnswer((_) async => true);
      final source = writeSourceFile('dup.txt', utf8.encode(chapterText));

      final result = await service.importBook(
        source,
        originalFileName: 'dup.txt',
      );

      expect(result.isLeft(), isTrue);
      expect(
        result.getLeft().toNullable()?.code,
        LibraryErrorCode.duplicateBook,
      );
      verifyNever(libraryBookStore.saveBookWithManifest(any, any));
    });

    test('双写失败时不做手工补偿删除，只清理已落盘的书籍文件', () async {
      when(
        libraryBookStore.saveBookWithManifest(any, any),
      ).thenAnswer((_) async => left('DB error'));
      final source = writeSourceFile('rollback.txt', utf8.encode(chapterText));

      final result = await service.importBook(
        source,
        originalFileName: 'rollback.txt',
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()?.code, LibraryErrorCode.saveFailed);
      // 双写在数据库事务中回滚，服务层不再调 deleteBook 补偿
      verifyNever(shelfRepo.deleteBook(any));
      expect(booksDir.existsSync(), isTrue);
      expect(booksDir.listSync().whereType<File>(), isEmpty);
    });
  });
}
