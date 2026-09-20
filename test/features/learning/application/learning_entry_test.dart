import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_entry.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';
import 'package:synlen/src/features/learning/presentation/widgets/word_definition_dialog.dart';

import '../word_definition_fixture.dart';
import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;

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

void main() {
  const query = WordLearningQuery(
    word: 'sorted',
    context: 'They sorted books.',
  );
  late ProviderContainer container;
  late _CachedRepository repository;
  var underlyingTaps = 0;

  Future<void> mount(
    WidgetTester tester, {
    EdgeInsets inset = EdgeInsets.zero,
  }) async {
    repository = _CachedRepository();
    container = ProviderContainer.test(
      overrides: [
        learningRepositoryProvider(query).overrideWith((_) => repository),
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => FakeLearningAudioPlayer.new,
        ),
      ],
    );
    underlyingTaps = 0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Padding(
          padding: inset,
          child: MaterialApp(
            navigatorKey: ToastService.navigatorKey,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  underlyingTaps++;
                },
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    final entry = container.read(learningEntryProvider.notifier);
    // 不 await 路由 Future：只等待卡片完成首帧。
    entry.showWord(
      word: query.word,
      context: query.context,
      anchorRect: const Rect.fromLTWH(300, 100, 60, 24),
      theme: ThemeData.light(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('透明屏障点击只关闭词卡，自动释放查询且下次点击恢复', (tester) async {
    await mount(tester);
    await open(tester);
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color?.a ?? 0, 0);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation!.isCancelled, isTrue);
    expect(underlyingTaps, 0);
    await tester.tapAt(const Offset(20, 20));
    expect(underlyingTaps, 1);
  });

  testWidgets('展示期间入口保持存活，重复调用不叠卡，返回键先关闭', (tester) async {
    await mount(tester);
    await open(tester);
    final first = container.read(learningEntryProvider.notifier);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(learningEntryProvider.notifier), same(first));
    await open(tester);
    expect(find.byType(WordDefinitionDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(ToastService.navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('全局锚点适应非零 overlay 原点，程序关闭只移除词卡', (tester) async {
    await mount(tester, inset: const EdgeInsets.only(left: 40, top: 30));
    await open(tester);
    final card = tester.getRect(find.byKey(const ValueKey('word-popover')));
    expect(card.top, 138);
    expect(card.center.dx, closeTo(330, 0.1));
    final entry = container.read(learningEntryProvider.notifier);
    final navigator = ToastService.navigatorKey.currentState!;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other route')),
      ),
    );
    await tester.pumpAndSettle();
    entry.dismissWord();
    entry.dismissWord();
    await tester.pumpAndSettle();
    expect(find.text('Other route'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(WordDefinitionDialog), findsNothing);
    expect(repository.cancellation!.isCancelled, isTrue);
  });
}
