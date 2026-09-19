import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

/// 真实 ZIP、文件与 SQLite 驱动导入入口，失败由数据库触发器注入。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppDatabase db;
  late BookImportService service;
  late File source;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-epub-import-');
    AppStorage.initForTesting(documentsPath: '${root.path}/documents');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BookImportService(
      shelfBookRepo: ShelfBookRepository(db: db),
      libraryBookStore: LibraryBookStore(db: db),
      fileStore: const BookFileStore(),
    );
    final archive = Archive()
      ..addFile(ArchiveFile.string('mimetype', 'application/epub+zip'))
      ..addFile(
        ArchiveFile.string(
          'META-INF/container.xml',
          '<container><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>',
        ),
      )
      ..addFile(
        ArchiveFile.string('content.opf', '''
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">test</dc:identifier><dc:title>导入验收</dc:title><dc:language>en</dc:language></metadata>
<manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="chapter"/></spine></package>'''),
      )
      ..addFile(
        ArchiveFile.string(
          'chapter.xhtml',
          '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Hello book.</p></body></html>',
        ),
      );
    source = await File(
      '${root.path}/source.epub',
    ).writeAsBytes(ZipEncoder().encode(archive));
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('导入产生可读原文件和匹配清单，重复导入不增加记录', () async {
    final result = await service.importBook(source, precomputedHash: 'hash');
    expect(result.isRight(), isTrue, reason: '$result');
    final books = await db.select(db.shelfBooks).get();
    final manifests = await db.select(db.bookManifests).get();
    expect(books.single.title, '导入验收');
    expect(manifests.single.spine.single.href, 'chapter.xhtml');
    expect(
      await File('${AppStorage.documentsPath}books/hash.epub').readAsBytes(),
      await source.readAsBytes(),
    );
    final duplicate = await service.importBook(source, precomputedHash: 'hash');
    expect(
      duplicate.getLeft().toNullable()!.code,
      LibraryErrorCode.duplicateBook,
    );
    expect(await db.select(db.shelfBooks).get(), hasLength(1));
  });

  test('第二张表失败时两表回滚，删除本次新文件并保留源文件', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_manifest BEFORE INSERT ON book_manifests BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    final result = await service.importBook(source, precomputedHash: 'hash');
    expect(result.getLeft().toNullable()!.code, LibraryErrorCode.saveFailed);
    expect(await db.select(db.shelfBooks).get(), isEmpty);
    expect(await db.select(db.bookManifests).get(), isEmpty);
    expect(
      await File('${AppStorage.documentsPath}books/hash.epub').exists(),
      isFalse,
    );
    expect(await source.exists(), isTrue);
  });

  test('解析失败不删除导入前已有的原文件', () async {
    final existing = File('${AppStorage.documentsPath}books/hash.epub');
    await existing.parent.create(recursive: true);
    await existing.writeAsString('已有文件');
    final result = await service.importBook(source, precomputedHash: 'hash');
    expect(result.isLeft(), isTrue);
    expect(await existing.readAsString(), '已有文件');
    expect(await db.select(db.shelfBooks).get(), isEmpty);
  });
}
