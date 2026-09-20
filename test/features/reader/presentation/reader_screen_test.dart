import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/providers/shared_preferences_provider.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_dialog.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_popover.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/reader/application/readium_gateway.dart';
import 'package:synlen/src/features/reader/application/readium_layout.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/presentation/control_panel.dart';
import 'package:synlen/src/features/reader/presentation/reader_screen.dart';
import 'package:synlen/src/features/reader/presentation/readium_viewport.dart';

import '../../learning/application/learning_audio_coordinator_test.dart'
    show FakeLearningAudioPlayer;
import '../../learning/word_definition_fixture.dart';

const _query = WordLearningQuery(word: 'sorted', context: 'They sorted books.');

class _CachedRepository implements LearningRepository {
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Queries implements BookQueries {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Gateway implements ReadiumGateway {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends ReadiumSession {
  _Session()
    : super(
        fileHash: 'book',
        prepare: (_) => throw UnimplementedError(),
        queries: _Queries(),
        gateway: _Gateway(),
      );

  final turns = <bool>[];

  @override
  Future<void> open(ReadiumLayout newLayout) async {
    layout = newLayout;
    publication = Publication.fromJson({
      'metadata': {'title': 'Reading'},
      'links': <Object>[],
      'readingOrder': [
        {'href': 'chapter.xhtml', 'type': 'application/xhtml+xml'},
      ],
    })!;
    locator = Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(
        progression: .2,
        position: 2,
        additionalProperties: const {'currentPage': 1},
      ),
    );
    ready = true;
  }

  @override
  void requestLayout(ReadiumLayout next) {}

  @override
  Future<bool> turnPage(bool forward, {required bool animated}) async {
    turns.add(forward);
    return true;
  }

  void emitLocator(Locator next) {
    locator = next;
    notifyListeners();
  }

  void emitReady(bool next) {
    ready = next;
    notifyListeners();
  }

  @override
  Future<bool> flush() async => true;
  @override
  Future<bool> close() async => true;
}

class _Factory extends ReaderSessionFactory {
  _Factory(this.session)
    : super(
        prepare: (_) => throw UnimplementedError(),
        queries: _Queries(),
        gateway: _Gateway(),
      );
  final _Session session;
  @override
  ReadiumSession create(String fileHash) => session;
}

void main() {
  late _Session session;
  late _CachedRepository repository;
  late ProviderContainer container;
  late SharedPreferences prefs;

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'reader_volume_key_turns_page': true,
    });
    prefs = await SharedPreferences.getInstance();
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
      (_) async => const StandardMessageCodec().encodeMessage([null]),
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        null,
      );
    });
    session = _Session();
    repository = _CachedRepository();
    container = ProviderContainer.test(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        readerSessionFactoryProvider.overrideWithValue(_Factory(session)),
        learningRepositoryProvider(_query).overrideWith((_) => repository),
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => FakeLearningAudioPlayer.new,
        ),
      ],
    );
    addTearDown(() async => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: ToastService.navigatorKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReaderScreen(fileHash: 'book'),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openWord(
    WidgetTester tester, {
    Map<String, Object> changes = const {},
  }) async {
    tester
        .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
        .onTextInteraction!(
      jsonEncode({
        'version': 1,
        'sessionId': session.sessionId,
        'resourceHref': session.locator!.href,
        'kind': 'word',
        'word': _query.word,
        'sentence': _query.context,
        'anchorRect': {'x': 30, 'y': 30, 'width': 64, 'height': 24},
        ...changes,
      }),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('底部Flutter留白短点打开多功能菜单', (tester) async {
    await mount(tester);
    final viewport = tester.getRect(find.byType(ReadiumViewport));
    final blank = Offset(206, viewport.bottom + 12);
    expect(viewport.contains(blank), isFalse);
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isFalse,
    );
    await tester.tapAt(blank);
    await tester.pump();
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isTrue,
    );
  });

  testWidgets('Readium词矩形转换为全局锚点，词卡期间暂停翻页且关闭后恢复', (tester) async {
    await mount(tester);
    final settings = container.read(readerSettingsProvider);
    final viewport = tester.getRect(find.byType(ReadiumViewport));
    final blank = Offset(206, viewport.bottom + 12);
    final controls = tester.widget<ControlPanel>(find.byType(ControlPanel));
    controls.onNextPage();
    expect(session.turns, [true]);

    await openWord(tester);
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(
      tester
          .widget<WordDefinitionPopover>(find.byType(WordDefinitionPopover))
          .anchorRect,
      Rect.fromLTWH(viewport.left + 30, viewport.top + 30, 64, 24),
    );
    expect(find.text('sort'), findsOneWidget);
    expect(find.text('sorted'), findsOneWidget);
    // 与音量键共用的翻页入口也要拒绝已经在途的事件。
    controls.onNextPage();
    controls.onPreviousPage();
    expect(session.turns, [true]);
    expect(container.read(readerSettingsProvider), same(settings));
    expect(prefs.getBool('reader_volume_key_turns_page'), isTrue);

    await tester.tapAt(blank);
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation!.isCancelled, isTrue);
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isFalse,
    );
    controls.onPreviousPage();
    expect(session.turns, [true, false]);
    expect(container.read(readerSettingsProvider), same(settings));
    expect(prefs.getBool('reader_volume_key_turns_page'), isTrue);
    await tester.tapAt(blank);
    await tester.pump();
    expect(
      tester.widget<ControlPanel>(find.byType(ControlPanel)).showControls,
      isTrue,
    );
  });

  testWidgets('旧会话和视口外词矩形不打开词卡', (tester) async {
    await mount(tester);
    await openWord(tester, changes: {'sessionId': 'stale-session'});
    expect(find.byType(WordDefinitionDialog), findsNothing);
    await openWord(
      tester,
      changes: {
        'anchorRect': {'x': 900, 'y': 900, 'width': 64, 'height': 24},
      },
    );
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation, isNull);
    await openWord(tester);
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
  });

  testWidgets('相同metrics通知保留词卡，实际视口变化关闭并取消学习', (tester) async {
    await mount(tester);
    await openWord(tester);
    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    expect(repository.cancellation!.isCancelled, isFalse);

    tester.view.physicalSize = const Size(430, 800);
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation!.isCancelled, isTrue);
  });

  testWidgets('同位置补齐正文保留词卡，位置改变后关闭并取消学习', (tester) async {
    await mount(tester);
    final original = session.locator!;
    final changedLocations = [
      original.copyWith(href: 'other.xhtml'),
      original.copyWith(
        locations: original.locations!.copyWith(progression: .4),
      ),
      original.copyWith(locations: original.locations!.copyWith(position: 3)),
      original.copyWith(
        locations: original.locations!.copyWith(
          additionalProperties: {'currentPage': 2},
        ),
      ),
    ];
    for (final next in changedLocations) {
      session.emitLocator(original);
      await tester.pump();
      await openWord(tester);
      session.emitLocator(
        original.copyWith(
          text: const LocatorText(highlight: 'They sorted books.'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WordDefinitionDialog), findsOneWidget);
      expect(repository.cancellation!.isCancelled, isFalse);

      session.emitLocator(next);
      await tester.pumpAndSettle();
      expect(find.byType(WordDefinitionDialog), findsNothing);
      expect(repository.cancellation!.isCancelled, isTrue);
    }
  });

  testWidgets('阅读器进入未就绪状态时关闭词卡并取消学习', (tester) async {
    await mount(tester);
    await openWord(tester);
    session.emitReady(false);
    await tester.pump();
    await tester.pump();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation!.isCancelled, isTrue);
  });
}
