import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
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
import 'package:synlen/src/features/learning/application/learning_entry.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/readium_viewport.dart';

import '../test/helpers/epub_fixture.dart';

/// 无网络设备验收：真实导入、原生分页、跨章、重排与完整 Locator 恢复。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // 测试框架默认消费设备输入，显式触摸验收才将其转发给原生视口。
  binding.shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'SYNLEN_NATIVE_GESTURE_PROBE',
  );
  testWidgets('Readium 阅读 TXT 与 EPUB，重排和重开保留阅读位置', (tester) async {
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
    final importer = BookImportService(
      shelfBookRepo: repository,
      libraryBookStore: LibraryBookStore(db: db),
      fileStore: const BookFileStore(),
    );
    final txt = await File('${root.path}/source.txt').writeAsString(
      List.generate(
        3,
        (chapter) =>
            '第${chapter + 1}章 阅读\n${List.generate(100, (i) => 'C${chapter + 1}-P${i + 1}. The reader keeps a record of every quiet morning. This paragraph provides enough text for pagination.').join('\n\n')}',
      ).join('\n\n'),
    );
    expect(
      (await importer.importBook(
        txt,
        precomputedHash: 'reader-smoke',
        originalFileName: '阅读验收.txt',
      )).isRight(),
      isTrue,
    );
    final epub = await File(
      '${root.path}/source.epub',
    ).writeAsBytes(testEpubBytes(chapter: _tableChapter));
    expect(
      (await importer.importBook(
        epub,
        precomputedHash: 'reader-epub-smoke',
        originalFileName: '表格与SVG.epub',
      )).isRight(),
      isTrue,
    );
    SharedPreferences.setMockInitialValues({
      'reader_page_animation': 0,
      'reader_zoom': 1.0,
    });
    final interactions = <Map<String, String?>>[];
    final container = ProviderContainer(
      overrides: [
        learningEntryProvider.overrideWith(
          () => _RecordingLearningEntry(interactions),
        ),
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
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
          path: '/reader/:hash',
          builder: (_, state) =>
              ReaderScreen(fileHash: state.pathParameters['hash']!),
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
    bool isReady() =>
        find.byType(ReadiumViewport).evaluate().isNotEmpty && session().ready;
    Future<void> open(String hash) async {
      unawaited(router.push<void>('/reader/$hash'));
      await _until(tester, isReady);
      await tester.pump(const Duration(milliseconds: 200));
      expect(session().failure, isNull);
    }

    Future<void> leave() async {
      final previous = session();
      router.go('/');
      await tester.pumpAndSettle();
      expect(await previous.close(), isTrue);
    }

    await open('reader-smoke');
    if (const bool.fromEnvironment('SYNLEN_NATIVE_GESTURE_PROBE')) {
      await _nativeGestureProbe(tester, session(), interactions);
      binding.reportData = {'nativeLearningInteractions': interactions};
    }
    expect(session().prepared!.path, endsWith('.epub'));
    expect(session().readingOrder, hasLength(3));
    final first = session().locator!.toJson();
    await session().turnPage(true, animated: false);
    await _until(
      tester,
      () => session().locator!.toJson().toString() != first.toString(),
    );
    expect(session().locator!.locations!.progression, greaterThan(0));
    await session().goToChapter(1);
    await _until(tester, () => session().chapterIndex == 1);
    for (var i = 0; i < 3; i++) {
      final progression = session().locator!.locations!.progression ?? 0;
      await session().turnPage(true, animated: false);
      await _until(
        tester,
        () => (session().locator!.locations!.progression ?? 0) > progression,
      );
    }
    await _nativeLayoutProbe(tester, 'before-layout', session());
    final beforeLayout = session().locator!;
    expect(beforeLayout.text?.highlight, isNotEmpty);
    final oldSessionId = session().sessionId;
    await container.read(readerSettingsProvider.notifier).setZoom(1.5);
    await _until(
      tester,
      () => isReady() && session().sessionId != oldSessionId,
    );
    expect(session().layout!.theme.zoom, 1.5);
    expect(session().initialLocator!.toJson(), beforeLayout.toJson());
    expect(session().chapterIndex, 1);
    await _nativeLayoutProbe(tester, 'after-layout', session());
    _expectSamePageRegion(beforeLayout, session().locator!);
    expect(session().locator!.text?.highlight, isNotEmpty);
    final beforeExit = session().locator!.toJson();
    await leave();
    final saved = (await repository.getBookByHash('reader-smoke'))!;
    expect(saved.progress!.locator, beforeExit);
    expect(saved.readingProgress, saved.progress!.fraction);
    expect(saved.progress!.chapterTitle, isNotEmpty);
    await open('reader-smoke');
    expect(session().initialLocator!.toJson(), saved.progress!.locator);
    expect(session().chapterIndex, 1);
    await _nativeLayoutProbe(tester, 'reopened', session());
    _expectSamePageRegion(Locator.fromJson(beforeExit)!, session().locator!);
    expect(session().locator!.text?.highlight, isNotEmpty);
    final savedPage = (beforeExit['locations'] as Map?)?['currentPage'];
    if (savedPage != null) {
      expect(
        (session().locator!.toJson()['locations'] as Map?)?['currentPage'],
        savedPage,
        reason: '同字号重开不得退回相邻页',
      );
    }
    binding.reportData = {
      ...?binding.reportData,
      'txtSavedLocator': beforeExit,
      'txtReopenedLocator': session().locator!.toJson(),
    };
    await leave();

    await open('reader-epub-smoke');
    expect(session().readingOrder, hasLength(1));
    await session().goTo('OEBPS/chapter.xhtml#table-end');
    await _until(
      tester,
      () => (session().locator!.locations!.progression ?? 0) > 0.7,
    );
    expect(session().failure, isNull);
    await _nativeLayoutProbe(tester, 'epub-end', session());
    binding.reportData!['epubEndLocator'] = session().locator!.toJson();
    await leave();
    for (var i = 0; i < 3; i++) {
      unawaited(router.push<void>('/reader/reader-smoke'));
      await _until(
        tester,
        () => find.byType(ReadiumViewport).evaluate().isNotEmpty,
      );
      await leave();
    }
    await open('reader-smoke');
    expect(session().initialLocator!.toJson(), saved.progress!.locator);
    await leave();
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    container.dispose();
    await db.close();
    await root.delete(recursive: true);
    expect(errors, isEmpty, reason: '正文可见时也不应产生阅读失败提示');
  });
}

String get _tableChapter =>
    '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>长表格与 SVG</title></head><body><h1>表格</h1><table><tbody>${List.generate(100, (i) => '<tr><td>TABLE_ROW_${i + 1}</td><td>${'A complete paragraph remains reachable after pagination. ' * 6}</td></tr>').join()}</tbody></table><p id="table-end">TABLE_AFTER_100_END</p><svg xmlns="http://www.w3.org/2000/svg" width="180" height="80" viewBox="0 0 180 80"><circle cx="40" cy="40" r="30" fill="blue"/></svg><p>AFTER_INLINE_SVG_VISIBLE</p></body></html>';

void _expectSamePageRegion(Locator before, Locator after) {
  expect(after.href, before.href);
  final pages = (after.toJson()['locations'] as Map?)?['totalPages'] as num?;
  final tolerance = pages == null || pages <= 0 ? 0.03 : 1.5 / pages;
  expect(
    after.locations?.progression ?? 0,
    closeTo(before.locations?.progression ?? 0, tolerance),
  );
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 40));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('Readium 等待原生就绪或 Locator 变化超时');
}

/// 停在真实排版结果上采集截图；HTTP 回调只访问会话，不调用测试器。
Future<void> _nativeLayoutProbe(
  WidgetTester tester,
  String phase,
  ReadiumSession session,
) async {
  if (!const bool.fromEnvironment('SYNLEN_NATIVE_LAYOUT_PROBE')) return;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8766);
  var finished = false;
  final subscription = server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'phase': phase,
        'ready': session.ready,
        'sessionId': session.sessionId,
        'locator': session.locator?.toJson(),
      }),
    );
    await request.response.close();
    if (request.uri.path == '/continue') finished = true;
  });
  try {
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (!finished && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, isTrue, reason: '排版截图探针 $phase 未收到 /continue');
  } finally {
    await subscription.cancel();
    await server.close(force: true);
  }
}

/// 真实视口事件经 ReaderScreen 分派到此入口，不创建学习请求或播放音频。
class _RecordingLearningEntry extends LearningEntry {
  _RecordingLearningEntry(this.events);
  final List<Map<String, String?>> events;

  @override
  Future<void> showWord({
    required String word,
    String? context,
    required Rect anchorRect,
    required ThemeData theme,
  }) async {
    events.add({'kind': 'word', 'word': word, 'sentence': context});
  }

  @override
  Future<void> showSentence({required String sentence}) async {
    events.add({'kind': 'sentence', 'sentence': sentence});
  }
}

/// 仅显式设备验收时监听回环地址，让 adb / XCTest 输入真正经过原生手势分发。
Future<void> _nativeGestureProbe(
  WidgetTester tester,
  ReadiumSession session,
  List<Map<String, String?>> events,
) async {
  final bounds = tester.getRect(find.byType(ReadiumViewport));
  final controls = tester
      .widget<ReadiumViewport>(find.byType(ReadiumViewport))
      .controls;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8766);
  var finished = false;
  int? longPressStart;
  void recordControls() =>
      events.add({'kind': 'controls', 'visible': controls.value.toString()});
  controls.addListener(recordControls);
  final subscription = server.listen((request) async {
    if (request.uri.path == '/reset') {
      controls.value = false;
      events.clear();
      longPressStart = null;
    }
    if (request.uri.path == '/arm') longPressStart = events.length;
    final hasWord = events.any((event) => event['kind'] == 'word');
    final hasSentence = events.any((event) => event['kind'] == 'sentence');
    final canFinish = hasWord && hasSentence && longPressStart != null;
    if (request.uri.path == '/finish' && !canFinish) {
      request.response.statusCode = 409;
    }
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'ready': session.ready,
        'sessionId': session.sessionId,
        'locator': session.locator?.toJson(),
        'events': events,
        'longPressStart': longPressStart,
        'controlsVisible': controls.value,
        'viewport': {
          'left': bounds.left,
          'top': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        },
      }),
    );
    await request.response.close();
    if (request.uri.path == '/finish' && canFinish) finished = true;
  });
  try {
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (!finished && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finished, isTrue, reason: '原生触摸探针未收到 /finish');
    final word = events.firstWhere((event) => event['kind'] == 'word');
    final sentence = events.firstWhere((event) => event['kind'] == 'sentence');
    expect(
      events.take(longPressStart!).map((event) => event['kind']),
      ['word'],
      reason: '短点只能触发一次点词，不得同时触发控制层',
    );
    final duringLongPress = events.skip(longPressStart!).toList();
    expect(duringLongPress.map((event) => event['kind']), [
      'sentence',
    ], reason: '长按不得同时触发点词或控制层');
    expect(word['word'], isNotEmpty);
    expect(sentence['sentence'], word['sentence']);
    expect(sentence['sentence'], contains(word['word']!));
    expect(
      sentence['sentence'],
      isIn([
        'The reader keeps a record of every quiet morning.',
        'This paragraph provides enough text for pagination.',
      ]),
    );
  } finally {
    controls.removeListener(recordControls);
    await subscription.cancel();
    await server.close(force: true);
  }
}
