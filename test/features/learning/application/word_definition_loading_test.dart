import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_controller.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';

import '../word_definition_fixture.dart';
import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;
import 'learning_controller_lifecycle_test.dart'
    show DeferredLearningRepository;

void main() {
  const query = WordLearningQuery(
    word: 'sorted',
    context: 'They sorted books.',
  );
  final provider = learningControllerProvider(query);
  late DeferredLearningRepository repository;
  late ProviderContainer container;
  late Completer<void> listening;

  setUp(() {
    repository = DeferredLearningRepository();
    listening = Completer<void>();
    repository.text.onListen = listening.complete;
    container = ProviderContainer.test(
      overrides: [
        learningAudioPlayerFactoryProvider.overrideWith(
          (_) => FakeLearningAudioPlayer.new,
        ),
        learningRepositoryProvider(query).overrideWith((_) => repository),
      ],
    );
    addTearDown(() => unawaited(repository.text.close()));
  });

  test('简义立即可读，无需下个网络记录触发；三个标签随后独立更新', () async {
    repository.info.complete(const LearningInfo(hasCachedAudio: true));
    final summaryReady = Completer<void>();
    final finished = Completer<void>();
    container.listen(provider, (_, next) {
      if (next.wordDefinition?.summary != null && !summaryReady.isCompleted) {
        summaryReady.complete();
      }
      if (next.wordDefinition?.isComplete == true && !next.isFetchingContent) {
        if (!finished.isCompleted) finished.complete();
      }
    });
    await listening.future;
    repository.text.add(wordSummaryRecord);
    await summaryReady.future.timeout(const Duration(seconds: 1));
    var state = container.read(provider);
    expect(state.isFetchingContent, isTrue);
    expect(state.wordDefinition!.summary!.lemma, 'sort');
    expect(state.wordDefinition!.summary!.phonetic, '/ˈsɔːrtɪd/');
    expect(state.wordDefinition!.explanation, isNull);
    expect(state.wordDefinition!.synonyms, isNull);

    repository.text.add(wordExplanationRecord);
    await container.pump();
    state = container.read(provider);
    expect(state.wordDefinition!.explanation, contains('sorted'));
    expect(state.wordDefinition!.synonyms, isNull);
    repository.text.add(wordSynonymsRecord);
    await container.pump();
    expect(
      container.read(provider).wordDefinition!.synonyms!.single.word,
      'classify',
    );
    repository.text.add(wordFormationRecord);
    await repository.text.close();
    await finished.future;
    expect(container.read(provider).content, wordDefinitionContent);
    expect(container.read(provider).contentError, isNull);
  });

  test('后续请求失败保留已验证简义，停止剩余标签加载', () async {
    repository.info.complete(const LearningInfo(hasCachedAudio: true));
    final failed = Completer<void>();
    container.listen(provider, (_, next) {
      if (next.contentError != null &&
          !next.isFetchingContent &&
          !failed.isCompleted) {
        failed.complete();
      }
    });
    await listening.future;
    repository.text.add(wordSummaryRecord);
    repository.text.addError(StateError('later section failed'));
    await failed.future.timeout(const Duration(seconds: 1));
    final state = container.read(provider);
    expect(state.wordDefinition!.summary!.definitionZh, '分类');
    expect(state.wordDefinition!.explanation, isNull);
    expect(state.wordDefinition!.isComplete, isFalse);
    expect(state.content, wordSummaryRecord);
    expect(state.contentError, isA<StateError>());
  });

  test('完整缓存直接生成所有标签，无需再次请求正文', () async {
    repository.info.complete(
      const LearningInfo(
        content: wordDefinitionContent,
        hasCachedContent: true,
        hasCachedAudio: true,
      ),
    );
    final loaded = Completer<void>();
    container.listen(provider, (_, next) {
      if (!next.isLoading && !loaded.isCompleted) loaded.complete();
    });
    await loaded.future;
    final state = container.read(provider);
    expect(state.wordDefinition!.isComplete, isTrue);
    expect(state.isFetchingContent, isFalse);
    expect(listening.isCompleted, isFalse);
  });

  test('损坏缓存当作未命中，保留缓存音频并重新生成正文', () async {
    repository.info.complete(
      const LearningInfo(
        content: 'broken cached content',
        hasCachedContent: true,
        hasCachedAudio: true,
      ),
    );
    final finished = Completer<void>();
    container.listen(provider, (_, next) {
      if (next.wordDefinition?.isComplete == true &&
          !next.isFetchingContent &&
          !finished.isCompleted) {
        finished.complete();
      }
    });
    await listening.future;
    expect(container.read(provider).content, isEmpty);
    expect(container.read(provider).hasAudio, isTrue);
    for (final record in wordDefinitionRecords) {
      repository.text.add(record);
    }
    await repository.text.close();
    await finished.future;
    expect(container.read(provider).wordDefinition!.isComplete, isTrue);
    expect(container.read(provider).contentError, isNull);
  });
}
