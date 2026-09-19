import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/core/database/providers.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/widgets/reader_stage.dart';

/// 无网络、无密钥的设备验收：真实 TXT 导入、WebView、翻章、排版和退出恢复。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('阅读会话在真实 WebView 中翻页、重新排版并恢复进度', (tester) async {
    final errors = <String>[];
    void recordError(LogEvent event) {
      if (event.level == Level.error || event.level == Level.fatal) {
        errors.add('${event.message}: ${event.error}');
      }
    }

    Logger.addLogListener(recordError);
    addTearDown(() => Logger.removeLogListener(recordError));
    final root = await (await getTemporaryDirectory()).createTemp(
      'reader-smoke-',
    );
    AppStorage.initForTesting(
      documentsPath: root.path,
      tempPath: '${root.path}/cache',
    );
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = ShelfBookRepository(db: db);
    final source = await File('${root.path}/source.txt').writeAsString(
      List.generate(
        3,
        (chapter) =>
            '第${chapter + 1}章 阅读\n${List.generate(60, (i) => 'The reader keeps a record of every quiet morning. This paragraph provides enough text for pagination.').join('\n\n')}',
      ).join('\n\n'),
    );
    final result =
        await BookImportService(
          shelfBookRepo: repository,
          libraryBookStore: LibraryBookStore(db: db),
          fileStore: const BookFileStore(),
        ).importBook(
          source,
          precomputedHash: 'reader-smoke',
          originalFileName: '阅读验收.txt',
        );
    expect(result.isRight(), isTrue);
    SharedPreferences.setMockInitialValues({'reader_page_animation': 0});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('书架')),
        ),
        GoRoute(
          path: '/reader',
          builder: (_, _) => const ReaderScreen(fileHash: 'reader-smoke'),
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
    // 从书架推入以经过转场，覆盖预加载 WebView 转为可见的控制器交接。
    unawaited(router.push<void>('/reader'));
    ReaderStage stage() => tester.widget<ReaderStage>(find.byType(ReaderStage));
    await _until(
      tester,
      () =>
          find.byType(ReaderStage).evaluate().isNotEmpty &&
          !stage().navigator.state.value.isBusy &&
          stage().navigator.state.value.totalPagesInChapter > 2,
    );
    final firstPage = stage().navigator.state.value.pageInChapter;
    stage().actions.onNextPage();
    await _until(
      tester,
      () =>
          stage().navigator.state.value.pageInChapter == firstPage + 1 &&
          !stage().navigator.state.value.isBusy,
    );
    stage().actions.onNextChapter();
    await _until(
      tester,
      () =>
          stage().navigator.state.value.spineIndex == 1 &&
          !stage().navigator.state.value.isBusy,
    );
    stage().actions.onNextPage();
    await _until(
      tester,
      () =>
          stage().navigator.state.value.pageInChapter > 0 &&
          !stage().navigator.state.value.isBusy,
    );
    final oldCount = stage().navigator.state.value.totalPagesInChapter;
    await container.read(readerSettingsProvider.notifier).setZoom(1.5);
    await _until(
      tester,
      () =>
          !stage().navigator.state.value.isBusy &&
          stage().navigator.state.value.totalPagesInChapter != oldCount,
    );
    final before = stage().navigator.state.value;
    expect(before.pageInChapter, greaterThan(0));
    router.go('/');
    await tester.pumpAndSettle();
    // 保存包含异步 SQLite I/O；用真实结果判断完成。
    for (var i = 0; i < 50; i++) {
      final saved = await repository.getBookByHash('reader-smoke');
      if (saved?.currentChapterIndex == 1 &&
          saved!.chapterScrollPosition! > 0) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    final saved = (await repository.getBookByHash('reader-smoke'))!;
    expect(saved.currentChapterIndex, 1);
    expect(
      saved.chapterScrollPosition,
      closeTo(before.pageInChapter / before.totalPagesInChapter, 0.001),
    );
    unawaited(router.push<void>('/reader'));
    await _until(
      tester,
      () =>
          find.byType(ReaderStage).evaluate().isNotEmpty &&
          !stage().navigator.state.value.isBusy,
    );
    expect(stage().navigator.state.value.spineIndex, 1);
    expect(stage().navigator.state.value.pageInChapter, before.pageInChapter);
    router.go('/');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
    expect(errors, isEmpty, reason: '正文可见时也不应产生阅读失败提示');
  });
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('阅读器等待就绪超时');
}
