import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/domain/word_definition.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_card.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_popover.dart';

const summary = WordSummary(
  lemma: 'sort',
  phonetic: '/ˈsɔːrtɪd/',
  partOfSpeech: 'verb',
  definitionEn: 'to put things into groups',
  definitionZh: '把事物分类',
);

void main() {
  Widget build(
    LearningDetailState state, {
    double scale = 1,
    Brightness brightness = Brightness.light,
    VoidCallback? retry,
    Future<void> Function()? play,
  }) => MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
    ),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: WordDefinitionPopover(
            anchorRect: const Rect.fromLTWH(140, 60, 50, 24),
            child: WordDefinitionCard(
              word: 'sorted',
              state: state,
              onPlayAudio: play ?? () async {},
              onRetry: retry ?? () {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('简义先展示，标签保留加载态，发音明确对应原词', (tester) async {
    var plays = 0;
    await tester.pumpWidget(
      build(
        const LearningDetailState(
          isLoading: false,
          isFetchingContent: true,
          hasAudio: true,
          wordDefinition: WordDefinition(summary: summary),
        ),
        play: () async {
          plays++;
        },
      ),
    );
    expect(find.text('sort'), findsOneWidget);
    expect(find.text('sorted'), findsOneWidget);
    expect(find.byKey(const ValueKey('word-summary')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-explanation')), findsNothing);
    await tester.tap(find.byTooltip('朗读原词“sorted”'));
    expect(plays, 1);
    await tester.ensureVisible(find.byKey(const ValueKey('word-tab-synonyms')));
    await tester.tap(find.byKey(const ValueKey('word-tab-synonyms')));
    expect(find.byKey(const ValueKey('word-synonyms')), findsNothing);
    expect(find.text('正在思考...'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换三个标签并展示可靠空态', (tester) async {
    await tester.pumpWidget(
      build(
        const LearningDetailState(
          isLoading: false,
          wordDefinition: WordDefinition(
            summary: summary,
            explanation: '在句中表示按类别分开。',
            synonyms: [],
            formation: '',
          ),
        ),
      ),
    );
    expect(find.text('在句中表示按类别分开。'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('word-tab-synonyms')));
    await tester.tap(find.byKey(const ValueKey('word-tab-synonyms')));
    await tester.pump();
    expect(find.text('当前语境下没有合适的近义词。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-tab-formation')));
    await tester.pump();
    expect(find.text('暂无可靠的构词信息。'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-tab-explanation')));
    await tester.pump();
    expect(find.text('在句中表示按类别分开。'), findsOneWidget);
  });

  testWidgets('加载、长释义与切标签都保持 35% 高度，选词标记跟随原词', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final card = find.byKey(const ValueKey('word-popover'));
    await tester.pumpWidget(build(const LearningDetailState()));
    final initial = tester.getRect(card);
    expect(initial.height, closeTo((800 - 24) * 0.35, 0.1));
    expect(
      tester.getRect(find.byKey(const ValueKey('word-selection-highlight'))),
      const Rect.fromLTWH(138, 58, 54, 28),
    );
    await tester.pumpWidget(
      build(
        LearningDetailState(
          isLoading: false,
          wordDefinition: WordDefinition(
            summary: summary,
            explanation: List.filled(30, '这里说明当前语境。').join(),
            synonyms: const [],
            formation: '',
          ),
        ),
      ),
    );
    expect(tester.getRect(card), initial);
    await tester.ensureVisible(
      find.byKey(const ValueKey('word-tab-formation')),
    );
    await tester.tap(find.byKey(const ValueKey('word-tab-formation')));
    await tester.pump();
    expect(tester.getRect(card), initial);
    expect(find.text('暂无可靠的构词信息。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('后续失败保留简义并可重试，内部错误不上屏', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      build(
        LearningDetailState(
          isLoading: false,
          wordDefinition: const WordDefinition(summary: summary),
          contentError: StateError('secret error'),
        ),
        retry: () {
          retries++;
        },
      ),
    );
    expect(find.byKey(const ValueKey('word-summary')), findsOneWidget);
    expect(find.textContaining('secret error'), findsNothing);
    await tester.ensureVisible(find.text('重试'));
    await tester.tap(find.text('重试'));
    expect(retries, 1);
  });

  for (final brightness in Brightness.values) {
    testWidgets('窄屏大字号可滚动阅读长内容：$brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        build(
          LearningDetailState(
            isLoading: false,
            wordDefinition: WordDefinition(
              summary: summary,
              explanation: List.filled(30, '这里说明当前语境。').join(),
              synonyms: const [],
              formation: '',
            ),
          ),
          scale: 2,
          brightness: brightness,
        ),
      );
      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(const ValueKey('word-popover')));
      expect(card.bottom, lessThanOrEqualTo(480));
      expect(card.top, greaterThan(84));
      await tester.drag(
        find.byKey(const ValueKey('word-card-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('word-card-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.pixels, greaterThan(0));
    });
  }
}
