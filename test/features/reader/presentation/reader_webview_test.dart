import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_dialog.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/application/book_session.dart';
import 'package:synlen/src/features/reader/application/book_webview_handler.dart';
import 'package:synlen/src/features/reader/application/reader_navigator.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/application/reader_viewport.dart';
import 'package:synlen/src/features/reader/application/reader_workflow.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';
import 'package:synlen/src/features/reader/domain/reader_settings.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/reader_webview.dart';
import 'package:synlen/src/features/reader/presentation/widgets/reader_stage.dart';

import '../../learning/application/learning_audio_coordinator_test.dart'
    show FakeLearningAudioPlayer;
import '../../learning/word_definition_fixture.dart';

class _Session extends Fake implements BookSession {}

class _Content extends Fake implements BookWebViewHandler {
  @override
  void clearCache() {}
}

class _ReadySession extends _Session {
  @override
  bool get isLoaded => true;
  @override
  ReaderBookView get book => (
    id: 1,
    title: '书',
    author: '',
    coverPath: null,
    filePath: '/book.txt',
    totalChapters: 1,
    direction: 0,
    currentChapterIndex: 0,
    chapterScrollPosition: 0.0,
  );
  @override
  int get direction => 0;
  @override
  List<SpineItem> get spine => [SpineItem(index: 0, href: 'chapter')];
  @override
  List<TocItem> get toc => [];
  @override
  Set<TocItem> resolveActiveItems(int index) => {};
}

class _ReadyWorkflow extends Fake implements ReaderWorkflow {
  _ReadyWorkflow(ReaderViewport viewport) {
    navigator = ReaderNavigator(session: book, viewport: viewport);
    navigator.state.value = const ReaderNavState(
      isLoading: false,
      totalPagesInChapter: 3,
    );
  }
  @override
  final BookSession book = _ReadySession();
  @override
  late final ReaderNavigator navigator;
  @override
  final failure = ValueNotifier<ReaderFailure?>(null);
  @override
  Future<bool> open() async => true;
  @override
  Future<bool> close() async {
    navigator.dispose();
    failure.dispose();
    return true;
  }
}

class _Factory extends ReaderSessionFactory {
  @override
  ReaderWorkflow createWorkflow(String fileHash, ReaderViewport viewport) =>
      _ReadyWorkflow(viewport);
  @override
  BookWebViewHandler createWebViewHandler() => _Content();
}

class _Settings extends ReaderSettingsNotifier {
  _Settings({this.volumeKeyTurnsPage = false});
  final bool volumeKeyTurnsPage;

  @override
  ReaderSettings build() => ReaderSettings(
    pageAnimation: ReaderPageAnimation.none,
    volumeKeyTurnsPage: volumeKeyTurnsPage,
  );
}

class _LearningRepository extends Fake implements LearningRepository {
  LearningCancellation? cancellation;

  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    return const LearningInfo(
      content: wordDefinitionContent,
      hasCachedContent: true,
      hasCachedAudio: true,
    );
  }
}

class _Controller extends PlatformInAppWebViewController {
  _Controller()
    : super.implementation(
        const PlatformInAppWebViewControllerCreationParams(id: 1),
      );
  final handlers = <String, JavaScriptHandlerCallback>{};
  final scripts = <String>[];

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {
    handlers[handlerName] = callback;
  }

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    scripts.add(source);
    return null;
  }

  @override
  dynamic getViewId() => 1;
  @override
  void dispose({bool isKeepAlive = false}) {}

  int get wordRequest =>
      int.parse(RegExp(r', (\d+)\)$').firstMatch(scripts.last)!.group(1)!);
  void word(int request) =>
      handlers['onWordTap']!(['word', 'a word.', 11, 22.5, 33, 44, request]);
}

class _Headless extends PlatformHeadlessInAppWebView {
  _Headless(super.params, this.controller, this.startup)
    : super.implementation();
  final _Controller controller;
  final Completer<void>? startup;
  var disposed = false;
  @override
  Future<void> run() async {
    if (startup != null) await startup!.future;
    disposed = false;
    params.onWebViewCreated?.call(params.controllerFromPlatform!(controller));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class _WebView extends PlatformInAppWebViewWidget {
  _WebView(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      params.controllerFromPlatform!(controller) as T;
  @override
  void dispose() {}
}

class _Platform extends InAppWebViewPlatform {
  final controller = _Controller();
  Completer<void>? startup;
  late _Headless headless;
  @override
  PlatformHeadlessInAppWebView createPlatformHeadlessInAppWebView(
    PlatformHeadlessInAppWebViewCreationParams params,
  ) => headless = _Headless(params, controller, startup);
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) => _WebView(params);
}

void main() {
  late _Platform platform;
  late ReaderWebViewController controller;
  late List<Rect> anchors;
  late List<String> sentences;
  setUp(() {
    platform = _Platform();
    InAppWebViewPlatform.instance = platform;
    controller = ReaderWebViewController();
    anchors = [];
    sentences = [];
  });

  testWidgets('进入时转场已经完成也会展示正文并启用点词', (tester) async {
    const channel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      channel,
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readerSessionFactoryProvider.overrideWith(_Factory.new),
          readerSettingsProvider.overrideWith(_Settings.new),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(fileHash: 'ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stage = tester.widget<ReaderStage>(find.byType(ReaderStage));
    expect(stage.shouldShowWebView, isTrue);
    expect(find.byType(InAppWebView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('真实词卡暂停翻页守卫，关闭后恢复且不改音量键设置', (tester) async {
    const channel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      channel,
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel,
        null,
      ),
    );
    const query = WordLearningQuery(word: 'word', context: 'a word.');
    final learning = _LearningRepository();
    final container = ProviderContainer.test(
      overrides: [
        readerSessionFactoryProvider.overrideWith(_Factory.new),
        readerSettingsProvider.overrideWith(
          () => _Settings(volumeKeyTurnsPage: true),
        ),
        learningRepositoryProvider(query).overrideWith((_) => learning),
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => FakeLearningAudioPlayer.new,
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: ToastService.navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(fileHash: 'ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final stage = tester.widget<ReaderStage>(find.byType(ReaderStage));
    final settings = container.read(readerSettingsProvider);
    final before = stage.navigator.state.value;
    expect(settings.volumeKeyTurnsPage, isTrue);
    expect(stage.canPerformPageTurn(true), isTrue);

    await stage.rendererController.webViewController!.checkTapElementAt(20, 30);
    platform.controller.word(platform.controller.wordRequest);
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(stage.canPerformPageTurn(true), isFalse);
    expect(stage.canPerformPageTurn(false), isFalse);
    expect(container.read(readerSettingsProvider), same(settings));
    expect(container.read(readerSettingsProvider).volumeKeyTurnsPage, isTrue);

    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(learning.cancellation!.isCancelled, isFalse);

    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(stage.canPerformPageTurn(true), isTrue);
    expect(stage.navigator.state.value, before);
    expect(container.read(readerSettingsProvider), same(settings));
    expect(container.read(readerSettingsProvider).volumeKeyTurnsPage, isTrue);
    expect(learning.cancellation!.isCancelled, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final changeSize in [true, false]) {
    testWidgets('${changeSize ? '视口尺寸' : '键盘遮挡'}变化关闭词卡并取消请求', (tester) async {
      const channel =
          'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        channel,
        (_) async => const StandardMessageCodec().encodeMessage([null]),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          channel,
          null,
        ),
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final learning = _LearningRepository();
      final container = ProviderContainer.test(
        overrides: [
          readerSessionFactoryProvider.overrideWith(_Factory.new),
          readerSettingsProvider.overrideWith(_Settings.new),
          learningRepositoryProvider.overrideWith((_, _) => learning),
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: ToastService.navigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ReaderScreen(fileHash: 'ready'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final stage = tester.widget<ReaderStage>(find.byType(ReaderStage));
      await stage.rendererController.webViewController!.checkTapElementAt(
        20,
        30,
      );
      platform.controller.word(platform.controller.wordRequest);
      await tester.pumpAndSettle();
      expect(find.byType(WordDefinitionDialog), findsOneWidget);
      if (changeSize) {
        tester.view.physicalSize = const Size(1000, 700);
      } else {
        tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      }
      await tester.pumpAndSettle();
      expect(find.byType(WordDefinitionDialog), findsNothing);
      expect(learning.cancellation!.isCancelled, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  Future<void> show(WidgetTester tester, {bool loading = false}) =>
      tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: 70,
                  width: 320,
                  height: 500,
                  child: ReaderWebView(
                    key: const ValueKey('reader'),
                    bookSession: _Session(),
                    webViewHandler: _Content(),
                    fileHash: 'test',
                    controller: controller,
                    isLoading: loading,
                    shouldShowWebView: true,
                    direction: 0,
                    initializeTheme: EpubTheme(
                      zoom: 1,
                      shouldOverrideTextColor: true,
                      colorScheme: const ColorScheme.light(),
                      padding: const EdgeInsets.all(25),
                    ),
                    callbacks: ReaderWebViewCallbacks(
                      onInitialized: () {},
                      onPageCountReady: (_) {},
                      onPageChanged: (_) {},
                      onScrollAnchors: (_) {},
                      onImageLongPress: (_, _) {},
                      onTap: (_, _) {},
                      onFootnoteTap: (_, _, _) {},
                      onLinkTap: (_) {},
                      shouldHandleLinkTap: (_) => false,
                      onWordTap: (_, _, rect) => anchors.add(rect),
                      onSentenceSelected: sentences.add,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('预载视图启动完成后才创建可见 WebView，避免创建第二个空白实例', (tester) async {
    platform.startup = Completer<void>();
    await show(tester);
    expect(find.byType(InAppWebView), findsNothing);
    platform.startup!.complete();
    await tester.pump();
    expect(find.byType(InAppWebView), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('退出后才启动完成的预载视图仍会释放，且不再绑定桥接', (tester) async {
    platform.startup = Completer<void>();
    await show(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    platform.startup!.complete();
    await tester.pump();
    expect(platform.headless.disposed, isTrue);
    expect(platform.controller.handlers, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('词锚点包含 WebView 真实偏移，不重复添加排版留白或设备像素比', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await show(tester);
    await controller.checkTapElementAt(20, 30);
    platform.controller.word(platform.controller.wordRequest);
    expect(anchors, [const Rect.fromLTWH(51, 92.5, 33, 44)]);
    platform.controller.handlers['onSentenceSelected']!(['A sentence.']);
    expect(sentences, ['A sentence.']);
  });

  testWidgets('重排、视口变化与卸载均丢弃在途词回执', (tester) async {
    await show(tester);
    await controller.checkTapElementAt(20, 30);
    final beforeLoading = platform.controller.wordRequest;
    await show(tester, loading: true);
    platform.controller.word(beforeLoading);
    expect(anchors, isEmpty);
    await show(tester);
    await controller.checkTapElementAt(20, 30);
    final beforeResize = platform.controller.wordRequest;
    platform.controller.handlers['onViewportResize']!([]);
    platform.controller.word(beforeResize);
    expect(anchors, isEmpty);
    await controller.checkTapElementAt(20, 30);
    final beforeDispose = platform.controller.wordRequest;
    await tester.pumpWidget(const SizedBox.shrink());
    platform.controller.word(beforeDispose);
    expect(anchors, isEmpty);
  });
}
