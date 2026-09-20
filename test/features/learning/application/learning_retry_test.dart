import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_controller.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';

import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;
import '../word_definition_fixture.dart';

class RetryLearningRepository implements LearningRepository {
  final queries = <LearningCancellation>[];
  @override
  Future<LearningInfo> getInfo(
    LearningQuery query, {
    LearningCancellation? cancellation,
  }) async {
    queries.add(cancellation!);
    if (queries.length == 1) throw StateError('temporary');
    return LearningInfo(
      content: query is WordLearningQuery ? wordDefinitionContent : '缓存释义',
      hasCachedContent: true,
      hasCachedAudio: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const wordQuery = WordLearningQuery(word: 'word', context: 'context');
  const sentenceQuery = SentenceLearningQuery(sentence: 'sentence');

  for (final isWord in [true, false]) {
    test('${isWord ? '单词' : '句子'}失败后重试取消旧会话、清除错误并复用缓存，连续触发不重复查询', () async {
      final query = isWord ? wordQuery : sentenceQuery;
      final cachedContent = isWord ? wordDefinitionContent : '缓存释义';
      final provider = learningControllerProvider(query);
      final repository = RetryLearningRepository();
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          learningRepositoryProvider(query).overrideWith((_) => repository),
        ],
      );
      final failed = Completer<void>();
      final recovered = Completer<void>();
      final subscription = container.listen(provider, (_, next) {
        if (next.contentError != null && !failed.isCompleted) failed.complete();
        if (next.content == cachedContent && !recovered.isCompleted) {
          recovered.complete();
        }
      });
      await failed.future.timeout(const Duration(seconds: 1));
      expect(container.read(provider).contentError, isA<StateError>());
      final retry = container.read(provider.notifier).retry;
      retry();
      retry();
      await container.pump();
      await recovered.future.timeout(const Duration(seconds: 1));
      expect(repository.queries, hasLength(2));
      expect(repository.queries.first.isCancelled, isTrue);
      expect(repository.queries.last.isCancelled, isFalse);
      expect(container.read(provider).content, cachedContent);
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      expect(repository.queries.last.isCancelled, isTrue);
    });
  }
}
