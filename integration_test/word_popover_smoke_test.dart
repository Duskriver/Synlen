import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/storage/app_storage.dart';
import 'package:synlen/src/features/learning/application/learning_audio_player.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_dialog.dart';
import 'package:synlen/src/features/library/data/library_book_store.dart';
import 'package:synlen/src/features/library/data/services/book_file_store.dart';
import 'package:synlen/src/features/library/data/services/book_import_service.dart';
import 'package:synlen/src/features/library/data/shelf_book_repository.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/reader_webview.dart';
import 'package:synlen/src/features/reader/presentation/widgets/reader_stage.dart';
import 'package:synlen/src/rust/frb_generated.dart';

/// 真实 TXT / EPUB 与 WebView，学习内容和音频在 provider 边界替换，无需密钥。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('点词浮卡逐步展示，关闭不翻页，重排和旋转释放会话', (tester) async {
    const volumeChannel = MethodChannel('synlen/volume_control');
    var volumeIntercepted = false;
    if (Platform.isAndroid) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(volumeChannel, (
        call,
      ) async {
        volumeIntercepted = switch (call.method) {
          'enableInterception' => true,
          'disableInterception' => false,
          _ => throw StateError('未知音量拦截方法：${call.method}'),
        };
        return null;
      });
    }
    await RustLib.init();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final root = await (await getTemporaryDirectory()).createTemp(
      'word-popover-',
    );
    AppStorage.initForTesting(
      documentsPath: root.path,
      tempPath: '${root.path}/cache',
    );
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final importer = BookImportService(
      shelfBookRepo: ShelfBookRepository(db: db),
      libraryBookStore: LibraryBookStore(db: db),
      fileStore: const BookFileStore(),
    );
    for (final extension in ['txt', 'epub']) {
      final source = await _source(root, extension);
      final imported = await importer.importBook(
        source,
        precomputedHash: 'word-$extension',
        originalFileName: 'word.$extension',
      );
      expect(imported.isRight(), isTrue, reason: '$imported');
    }
    SharedPreferences.setMockInitialValues({
      'reader_page_animation': 0,
      'reader_volume_key_turns_page': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = _WordRepository();
    final players = <_SilentPlayer>[];
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        learningRepositoryProvider.overrideWith((_, _) => repository),
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => () {
            final player = _SilentPlayer();
            players.add(player);
            return player;
          },
        ),
      ],
    );
    final router = GoRouter(
      navigatorKey: ToastService.navigatorKey,
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
      await db.close();
      await root.delete(recursive: true);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (Platform.isAndroid) {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(
          volumeChannel,
          null,
        );
      }
    });
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

    unawaited(router.push<void>('/reader/word-txt'));
    await _readerReady(tester);
    if (Platform.isAndroid) expect(volumeIntercepted, isTrue);
    await _openWord(tester);
    final first = repository.requests.last;
    await _until(tester, () => _content('summary').evaluate().isNotEmpty);
    expect(_content('explanation'), findsNothing);
    expect(_content('synonyms'), findsNothing);
    await _selectTab(tester, 'synonyms');
    expect(_content('synonyms'), findsNothing);
    first.finish();
    await _until(tester, () => _content('synonyms').evaluate().isNotEmpty);
    await _selectTab(tester, 'formation');
    await _until(tester, () => _content('formation').evaluate().isNotEmpty);
    await _selectTab(tester, 'explanation');
    await _until(tester, () => _content('explanation').evaluate().isNotEmpty);
    _expectCardInsideScreen(tester);

    final before = _stage(tester).navigator.state.value;
    if (Platform.isAndroid) {
      expect(volumeIntercepted, isFalse);
      // 放开原生拦截后，已经发出的音量事件仍不能穿过词卡翻页。
      await _volumeDown(binding);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        _stage(tester).navigator.state.value.spineIndex,
        before.spineIndex,
      );
      expect(
        _stage(tester).navigator.state.value.pageInChapter,
        before.pageInChapter,
      );
      expect(find.byType(WordDefinitionDialog), findsOneWidget);
    }
    await _dismissOutside(tester);
    final after = _stage(tester).navigator.state.value;
    expect(after.spineIndex, before.spineIndex);
    expect(after.pageInChapter, before.pageInChapter);
    await _until(
      tester,
      () => first.cancellation.isCancelled && players.last.closed,
    );
    if (Platform.isAndroid) {
      expect(volumeIntercepted, isTrue);
      await _volumeDown(binding);
      await _until(
        tester,
        () =>
            !_stage(tester).navigator.state.value.isBusy &&
            _stage(tester).navigator.state.value.pageInChapter ==
                before.pageInChapter + 1,
      );
    }

    await _openWord(tester, verticalFraction: 0.25);
    final reflow = repository.requests.last;
    await container.read(readerSettingsProvider.notifier).setZoom(1.3);
    await _until(
      tester,
      () => find.byType(WordDefinitionDialog).evaluate().isEmpty,
    );
    await _until(tester, () => reflow.cancellation.isCancelled);
    await _readerReady(tester);

    await _openWord(tester, verticalFraction: 0.75);
    final rotation = repository.requests.last;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
    ]);
    await _until(
      tester,
      () => tester.view.physicalSize.width > tester.view.physicalSize.height,
    );
    await _until(
      tester,
      () => find.byType(WordDefinitionDialog).evaluate().isEmpty,
    );
    await _until(tester, () => rotation.cancellation.isCancelled);
    await _readerReady(tester);
    await _openWord(tester);
    _expectCardInsideScreen(tester);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await _until(
      tester,
      () => tester.view.physicalSize.height > tester.view.physicalSize.width,
    );
    await _until(
      tester,
      () => find.byType(WordDefinitionDialog).evaluate().isEmpty,
    );

    router.go('/');
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/reader/word-epub'));
    await _readerReady(tester);
    await _openWord(tester, verticalFraction: 0.25);
    final epub = repository.requests.last;
    await _until(tester, () => _content('summary').evaluate().isNotEmpty);
    _expectCardInsideScreen(tester);
    router.go('/');
    await _until(
      tester,
      () => find.byType(WordDefinitionDialog).evaluate().isEmpty,
    );
    await _until(
      tester,
      () => epub.cancellation.isCancelled && players.last.closed,
    );
    if (Platform.isAndroid) expect(volumeIntercepted, isFalse);
  });
}

Finder _content(String section) => find.byKey(ValueKey('word-$section'));
Finder _tab(String section) => find.byKey(ValueKey('word-tab-$section'));
Future<void> _selectTab(WidgetTester tester, String section) async {
  await tester.ensureVisible(_tab(section));
  await tester.tap(_tab(section));
}

ReaderStage _stage(WidgetTester tester) =>
    tester.widget<ReaderStage>(find.byType(ReaderStage));

Future<void> _readerReady(WidgetTester tester) => _until(
  tester,
  () =>
      find.byType(ReaderStage).evaluate().isNotEmpty &&
      _stage(tester).shouldShowWebView &&
      !_stage(tester).navigator.state.value.isBusy &&
      _stage(tester).navigator.state.value.totalPagesInChapter > 1,
);

Future<void> _openWord(
  WidgetTester tester, {
  double verticalFraction = 0.5,
}) async {
  final point = await _visibleWordPoint(tester, verticalFraction);
  expect(_stage(tester).showControls, isFalse);
  await tester.tapAt(point);
  await _until(
    tester,
    () => find.byType(WordDefinitionDialog).evaluate().isNotEmpty,
  );
  await _until(tester, () => _content('summary').evaluate().isNotEmpty);
}

Future<void> _volumeDown(IntegrationTestWidgetsFlutterBinding binding) async {
  await binding.defaultBinaryMessenger.handlePlatformMessage(
    'synlen/volume_events',
    const StandardMethodCodec().encodeSuccessEnvelope('down'),
    null,
  );
}

// 只读 DOM 定位完整可见的 fixture 单词，点击仍经过 Flutter 手势与正式取词桥接。
Future<Offset> _visibleWordPoint(
  WidgetTester tester,
  double verticalFraction,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  Object? lastDiagnostic;
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    final finder = find.byType(InAppWebView);
    final webView = tester.widget<InAppWebView>(finder);
    final controller =
        webView.platform.params.headlessWebView?.webViewController;
    final bounds = tester.getRect(finder);
    final padding = tester
        .widget<ReaderWebView>(find.byType(ReaderWebView))
        .initializeTheme
        .padding;
    final safeWidth = (bounds.width - padding.horizontal).floor();
    final safeHeight = (bounds.height - padding.vertical).floor();
    final result = await controller?.evaluateJavascript(
      source:
          '''
(() => {
  if (Math.abs(innerWidth - ${bounds.width}) > 1 ||
      Math.abs(innerHeight - ${bounds.height}) > 1) {
    return {diagnostic: [innerWidth, innerHeight, ${bounds.width}, ${bounds.height}]};
  }
  const frame = document.getElementById('frame-curr');
  const doc = frame?.contentDocument;
  if (!doc?.body) return {diagnostic: 'missing frame body'};
  const style = doc.defaultView.getComputedStyle(doc.documentElement);
  const safe = [parseFloat(style.getPropertyValue('--synlen-safe-width')),
    parseFloat(style.getPropertyValue('--synlen-safe-height'))];
  if (safe[0] !== $safeWidth || safe[1] !== $safeHeight) {
    return {diagnostic: ['pagination pending', ...safe, $safeWidth, $safeHeight]};
  }
  const offset = frame.getBoundingClientRect();
  const walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
  const candidates = [];
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    let left = 0, top = 0, right = frame.clientWidth, bottom = frame.clientHeight;
    for (let element = node.parentElement; element; element = element.parentElement) {
      const style = doc.defaultView.getComputedStyle(element);
      const bounds = element.getBoundingClientRect();
      if (['auto', 'scroll', 'hidden', 'clip'].includes(style.overflowX)) {
        left = Math.max(left, bounds.left); right = Math.min(right, bounds.right);
      }
      if (['auto', 'scroll', 'hidden', 'clip'].includes(style.overflowY)) {
        top = Math.max(top, bounds.top); bottom = Math.min(bottom, bounds.bottom);
      }
    }
    for (const match of node.textContent.matchAll(/sorted/g)) {
      const range = doc.createRange();
      range.setStart(node, match.index);
      range.setEnd(node, match.index + match[0].length);
      for (const rect of range.getClientRects()) {
        if (rect.width <= 0 || rect.height <= 0 || rect.left < left ||
            rect.top < top || rect.right > right || rect.bottom > bottom) continue;
        const x = offset.left + frame.clientLeft + rect.x + rect.width / 2;
        const y = offset.top + frame.clientTop + rect.y + rect.height / 2;
        if (x < 0 || y < 0 || x > innerWidth || y > innerHeight) continue;
        candidates.push({x, y, distance: Math.abs(x - innerWidth / 2) +
          Math.abs(y - innerHeight * $verticalFraction) * 2});
      }
    }
  }
  candidates.sort((a, b) => a.distance - b.distance);
  return candidates[0] ?? {diagnostic: [frame.clientWidth, frame.clientHeight,
    doc.body.innerText.slice(0, 120), doc.body.getBoundingClientRect().toJSON()]};
})()
''',
    );
    if (result is Map &&
        result.containsKey('x') &&
        !_stage(tester).navigator.state.value.isBusy) {
      return bounds.topLeft +
          Offset(
            (result['x'] as num).toDouble(),
            (result['y'] as num).toDouble(),
          );
    }
    lastDiagnostic = 'controller=${controller != null} result=$result';
  }
  fail('正文未提供与当前视口匹配的可见单词：$lastDiagnostic');
}

Future<void> _dismissOutside(WidgetTester tester) async {
  final bounds = tester.getRect(find.byKey(const ValueKey('word-popover')));
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final outside = [
    Offset(size.width / 2, size.height * 0.15),
    Offset(size.width / 2, size.height * 0.85),
    Offset(12, size.height / 2),
  ].firstWhere((point) => !bounds.contains(point));
  await tester.tapAt(outside);
  await _until(
    tester,
    () => find.byType(WordDefinitionDialog).evaluate().isEmpty,
  );
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byType(WordDefinitionDialog), findsNothing);
}

void _expectCardInsideScreen(WidgetTester tester) {
  final card = tester.getRect(find.byKey(const ValueKey('word-popover')));
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(card.left, greaterThanOrEqualTo(0));
  expect(card.top, greaterThanOrEqualTo(0));
  expect(card.right, lessThanOrEqualTo(size.width));
  expect(card.bottom, lessThanOrEqualTo(size.height));
  expect(tester.takeException(), isNull);
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
  }
  fail('词卡设备验收等待超时');
}

Future<File> _source(Directory root, String extension) async {
  final paragraphs = List.generate(
    50,
    (_) => '${List.filled(24, 'sorted').join(' ')}.',
  );
  final file = File('${root.path}/source.$extension');
  if (extension == 'txt') return file.writeAsString(paragraphs.join('\n\n'));
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
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">word</dc:identifier><dc:title>词卡验收</dc:title><dc:language>en</dc:language></metadata>
<manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="chapter"/></spine></package>'''),
    )
    ..addFile(
      ArchiveFile.string(
        'chapter.xhtml',
        '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Words</title></head><body>${paragraphs.map((text) => '<p>$text</p>').join()}</body></html>',
      ),
    );
  return file.writeAsBytes(ZipEncoder().encode(archive));
}

class _WordRepository implements LearningRepository {
  final requests = <_WordRequest>[];

  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async => const LearningInfo(hasCachedAudio: true);

  @override
  Stream<String> getContentStream(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) {
    final request = _WordRequest(cancellation!);
    requests.add(request);
    request.stream.add(
      jsonEncode({
        'type': 'summary',
        'lemma': 'sort',
        'phonetic': '/ˈsɔːrtɪd/',
        'partOfSpeech': 'verb',
        'definitionEn': 'put things into groups',
        'definitionZh': '分类',
      }),
    );
    return request.stream.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WordRequest {
  _WordRequest(this.cancellation) {
    cancellation.onCancel(() => unawaited(stream.close()));
  }
  final LearningCancellation cancellation;
  final stream = StreamController<String>();

  void finish() {
    for (final record in [
      {'type': 'explanation', 'text': '这里 sorted 表示按类别分开。'},
      {
        'type': 'synonyms',
        'items': [
          {'word': 'classify', 'meaning': '分类', 'distinction': '更强调按既定标准划分类别。'},
        ],
      },
      {'type': 'formation', 'text': 'sort 加 -ed 构成过去分词 sorted。'},
    ]) {
      stream.add(jsonEncode(record));
    }
    unawaited(stream.close());
  }
}

class _SilentPlayer implements LearningAudioPlayer {
  bool closed = false;
  @override
  bool get isStopped => true;
  @override
  Future<void> openPlayer() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> stopPlayer() async {}
  @override
  Future<void> closePlayer() async => closed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
