import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/reader/application/readium_gateway.dart';
import 'package:synlen/src/features/reader/application/readium_publication_source.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/readium_viewport.dart';

import '../test/helpers/epub_fixture.dart';

/// Android profile/release 同机比较；首开缓存为空，重开恢复书中位置。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Android 图书首开与重开阶段耗时', (tester) async {
    expect(Platform.isAndroid, isTrue);
    expect(kDebugMode, isFalse, reason: '性能测量必须使用 profile 或 release');
    final root = await (await getTemporaryDirectory()).createTemp(
      'reader-perf-',
    );
    AppStorage.initForTesting(
      documentsPath: root.path,
      tempPath: '${root.path}/cache',
    );
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = ShelfBookRepository(db: db);
    final importer = BookImportService(
      shelfBookRepo: repository,
      libraryBookStore: LibraryBookStore(db: db),
      fileStore: const BookFileStore(),
    );
    final epub = await File(
      '${root.path}/source.epub',
    ).writeAsBytes(_largeEpub());
    expect(
      (await importer.importBook(
        epub,
        precomputedHash: 'reader-perf',
        originalFileName: '性能测量.epub',
      )).isRight(),
      isTrue,
    );
    SharedPreferences.setMockInitialValues({
      'reader_page_animation': 0,
      'reader_zoom': 1.0,
    });
    final samples = <Map<String, Object?>>[];
    var sample = <String, Object?>{};
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        readerSessionFactoryProvider.overrideWith((ref) {
          final source = ref.watch(readiumPublicationSourceProvider);
          final factory = ReaderSessionFactory(
            queries: ref.watch(bookQueriesProvider),
            prepare: (hash) async {
              final watch = Stopwatch()..start();
              final result = await source.open(hash);
              sample['prepareMs'] = watch.elapsedMicroseconds / 1000;
              return result;
            },
            gateway: _TimedGateway(
              FlutterReadium(),
              (ms) => sample['nativeOpenMs'] = ms,
            ),
          );
          ref.onDispose(factory.dispose);
          return factory;
        }),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('书架')),
        ),
        GoRoute(
          path: '/reader',
          builder: (_, _) => const ReaderScreen(fileHash: 'reader-perf'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    ReadiumSession session() =>
        tester.widget<ReadiumViewport>(find.byType(ReadiumViewport)).session;
    Locator? saved;
    for (var run = 0; run < 6; run++) {
      sample = {'run': run, 'cache': run == 0 ? 'cold' : 'warm'};
      final watch = Stopwatch()..start();
      unawaited(router.push<void>('/reader'));
      await _until(
        tester,
        () => find.byType(ReadiumViewport).evaluate().isNotEmpty,
      );
      sample['viewportMs'] = watch.elapsedMicroseconds / 1000;
      await _until(tester, () => session().ready);
      sample['readyMs'] = watch.elapsedMicroseconds / 1000;
      expect(session().failure, isNull);
      expect(session().readingOrder, hasLength(_chapters));
      expect(session().locator?.text?.highlight, isNotEmpty);
      if (saved != null) {
        expect(session().initialLocator!.toJson(), saved.toJson());
        expect(session().locator!.href, saved.href);
        expect(
          session().locator!.locations?.progression ?? 0,
          closeTo(saved.locations?.progression ?? 0, 0.03),
        );
      }
      samples.add(sample);
      if (run == 0) {
        await session().goToChapter(_chapters ~/ 2);
        await _until(tester, () => session().chapterIndex == _chapters ~/ 2);
        await session().turnPage(true, animated: false);
        await _until(
          tester,
          () => (session().locator!.locations?.progression ?? 0) > 0,
        );
      }
      await tester.pump(const Duration(milliseconds: 300));
      saved = session().locator;
      final previous = session();
      router.go('/');
      await tester.pumpAndSettle();
      expect(await previous.close(), isTrue);
      await tester.pump(const Duration(milliseconds: 500));
    }
    binding.reportData = {
      'mode': kProfileMode ? 'profile' : 'release',
      'chapters': _chapters,
      'paragraphsPerChapter': _paragraphs,
      'epubBytes': await epub.length(),
      'samples': samples,
    };
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 5)));
}

const _chapters = 120;
const _paragraphs = 100;

List<int> _largeEpub() {
  final extra = <String, List<int>>{};
  for (var i = 0; i < _chapters; i++) {
    extra['OEBPS/chapter$i.xhtml'] = utf8.encode(
      '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter $i</title></head><body><h1>Chapter $i</h1>'
      '${List.generate(_paragraphs, (p) => '<p id="p$p">C$i P$p. ${'The reader keeps a record of every quiet morning. This paragraph provides enough text for pagination. ' * 4}</p>').join()}'
      '</body></html>',
    );
  }
  extra['OEBPS/package.opf'] = utf8.encode(
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">urn:synlen:performance</dc:identifier><dc:title>性能测量</dc:title><dc:language>en</dc:language><meta property="dcterms:modified">2000-01-01T00:00:00Z</meta></metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
    '${List.generate(_chapters, (i) => '<item id="c$i" href="chapter$i.xhtml" media-type="application/xhtml+xml"/>').join()}</manifest><spine>'
    '${List.generate(_chapters, (i) => '<itemref idref="c$i"/>').join()}</spine></package>',
  );
  extra['OEBPS/nav.xhtml'] = utf8.encode(
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><ol>'
    '${List.generate(_chapters, (i) => '<li><a href="chapter$i.xhtml">Chapter $i</a></li>').join()}</ol></nav></body></html>',
  );
  return testEpubBytes(extra: extra);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 10));
    if (ready()) return;
  }
  fail('等待 Readium 正文就绪或位置更新超时');
}

class _TimedGateway extends NativeReadiumGateway {
  _TimedGateway(super.readium, this.record);
  final void Function(double) record;

  @override
  Future<Publication> open(String path, EPUBPreferences preferences) async {
    final watch = Stopwatch()..start();
    final result = await super.open(path, preferences);
    record(watch.elapsedMicroseconds / 1000);
    return result;
  }
}
