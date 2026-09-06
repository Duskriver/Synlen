import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/word_learning_controller.dart';
import 'package:synlen/src/features/learning/application/sentence_learning_controller.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

import 'learning_audio_coordinator_test.dart' show FakeLearningAudioPlayer;

class RetryWordRepository implements WordRepository {
  final queries = <LearningCancellation>[];
  @override
  Future<WordLearningResult> getWordInfo(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) async {
    queries.add(cancellation!);
    if (queries.length == 1) throw StateError('temporary');
    return WordLearningResult(
      explanation: '缓存释义',
      hasCachedExplanation: true,
      hasCachedAudio: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RetrySentenceRepository implements SentenceRepository {
  final queries = <LearningCancellation>[];
  @override
  Future<SentenceLearningResult> getSentenceInfo(
    String sentence, {
    LearningCancellation? cancellation,
  }) async {
    queries.add(cancellation!);
    if (queries.length == 1) throw StateError('temporary');
    return SentenceLearningResult(
      analysis: '缓存释义',
      hasCachedAnalysis: true,
      hasCachedAudio: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final isWord in [true, false]) {
    test('${isWord ? '单词' : '句子'}失败后重试取消旧会话、清除错误并复用缓存，连续触发不重复查询', () async {
      final word = RetryWordRepository();
      final sentence = RetrySentenceRepository();
      final container = ProviderContainer.test(
        overrides: [
          learningAudioPlayerFactoryProvider.overrideWith(
            (_) => FakeLearningAudioPlayer.new,
          ),
          wordRepositoryProvider.overrideWith((_) => word),
          sentenceRepositoryProvider.overrideWith((_) => sentence),
        ],
      );
      final wordProvider = wordLearningControllerProvider(
        const WordLearningRequest(word: 'word', context: 'context'),
      );
      final sentenceProvider = sentenceLearningControllerProvider('sentence');
      final provider = isWord ? wordProvider : sentenceProvider;
      final failed = Completer<void>();
      final recovered = Completer<void>();
      final subscription = container.listen(provider, (_, next) {
        if (next.contentError != null && !failed.isCompleted) failed.complete();
        if (next.content == '缓存释义' && !recovered.isCompleted) {
          recovered.complete();
        }
      });
      await failed.future.timeout(const Duration(seconds: 1));
      expect(container.read(provider).contentError, isA<StateError>());
      final retry = isWord
          ? container.read(wordProvider.notifier).retry
          : container.read(sentenceProvider.notifier).retry;
      retry();
      retry();
      await container.pump();
      await recovered.future.timeout(const Duration(seconds: 1));
      final queries = isWord ? word.queries : sentence.queries;
      expect(queries, hasLength(2));
      expect(queries.first.isCancelled, isTrue);
      expect(queries.last.isCancelled, isFalse);
      expect(container.read(provider).content, '缓存释义');
      expect(container.read(provider).contentError, isNull);
      subscription.close();
      await container.pump();
      expect(queries.last.isCancelled, isTrue);
    });
  }
}
