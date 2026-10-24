import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';

import '../test/helpers/epub_fixture.dart';

/// 两端真实插件验收：后台 ZIP 读取、原生图片压缩、数据库与文件补偿。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('批量导入含封面的 EPUB，压缩产物可解码，失败不残留文件', (tester) async {
    final root = await (await getTemporaryDirectory()).createTemp(
      'cover-import-',
    );
    AppStorage.initForTesting(documentsPath: '${root.path}/documents');
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final service = BookImportService(
      shelfBookRepo: ShelfBookRepository(db: db),
      libraryBookStore: LibraryBookStore(db: db),
      fileStore: const BookFileStore(),
    );
    final source = await File(
      '${root.path}/source.epub',
    ).writeAsBytes(testEpubBytes(cover: testCoverPngBytes()));
    final samples = <int>[];
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      final result = await service.importBook(
        source,
        precomputedHash: 'cover-$i',
      );
      samples.add(watch.elapsedMilliseconds);
      expect(result.isRight(), isTrue, reason: '$result');
      final book = result.getRight().toNullable()!;
      expect(book.coverPath, 'covers/cover-$i.jpg');
      final bytes = await File(
        '${AppStorage.documentsPath}${book.coverPath}',
      ).readAsBytes();
      expect(bytes.take(2), [0xff, 0xd8]);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1);
      expect(frame.image.height, 1);
      frame.image.dispose();
      codec.dispose();
    }
    expect(await db.select(db.shelfBooks).get(), hasLength(5));
    await db.customStatement(
      "CREATE TRIGGER reject_manifest BEFORE INSERT ON book_manifests BEGIN SELECT RAISE(ABORT, 'failure'); END",
    );
    final failed = await service.importBook(source, precomputedHash: 'failed');
    expect(failed.getLeft().toNullable()!.code, LibraryErrorCode.saveFailed);
    expect(
      await File('${AppStorage.documentsPath}covers/failed.jpg').exists(),
      isFalse,
    );
    expect(
      await File('${AppStorage.documentsPath}books/failed.epub').exists(),
      isFalse,
    );
    expect(await db.select(db.shelfBooks).get(), hasLength(5));
    binding.reportData = {
      'platform': Platform.operatingSystem,
      'importMs': samples,
    };
  });
}
