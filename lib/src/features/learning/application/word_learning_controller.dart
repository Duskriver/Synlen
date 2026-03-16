import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';

part 'word_learning_controller.g.dart';

@immutable
class WordLearningRequest {
  final String word;
  final String context;

  const WordLearningRequest({required this.word, required this.context});

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WordLearningRequest &&
            runtimeType == other.runtimeType &&
            word == other.word &&
            context == other.context;
  }

  @override
  int get hashCode => Object.hash(word, context);
}

typedef WordLearningState = LearningDetailState;

@riverpod
class WordLearningController extends _$WordLearningController {
  late final LearningAudioCoordinator _audio;

  @override
  WordLearningState build(WordLearningRequest request) {
    _audio = LearningAudioCoordinator(
      debugLabel: 'Word',
      onPlaybackError: (error) {
        _updateState(
          (current) => current.copyWith(audioError: formatLearningError(error)),
        );
      },
    );
    ref.onDispose(_audio.dispose);
    unawaited(_loadData(request));
    return const WordLearningState();
  }

  Future<void> playAudio() => _audio.play(state.audioUrl);

  Future<void> _loadData(WordLearningRequest request) async {
    try {
      await _audio.initialize();

      final repository = ref.read(wordRepositoryProvider);
      final result = await repository.getWordInfo(
        request.word,
        request.context,
      );
      if (_audio.isDisposed) {
        return;
      }

      state = WordLearningState(
        isLoading: false,
        isFetchingContent: !result.hasCachedExplanation,
        isFetchingAudio: !result.hasCachedAudio,
        content: result.explanation ?? '',
        audioUrl: result.audioUrl,
        hasAudio: result.hasCachedAudio,
      );

      await _audio.prepareLocalSource(result.audioUrl);
      if (_audio.isDisposed) {
        return;
      }

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(request.word));
      }

      if (result.hasCachedExplanation) {
        _updateState((current) => current.copyWith(isFetchingContent: false));
      } else {
        await _fetchExplanation(request.word, request.context);
      }
    } catch (error) {
      _updateState(
        (current) => current.copyWith(
          isLoading: false,
          isFetchingContent: false,
          isFetchingAudio: false,
          contentError: formatLearningError(error),
        ),
      );
    }
  }

  Future<String?> _fetchAndCacheAudio(String word) async {
    try {
      final repository = ref.read(wordRepositoryProvider);
      await for (final result in repository.getPronunciationStream(word)) {
        final session = await _audio.attachStreamingSource(result);
        if (session == null) {
          return null;
        }

        _updateState(
          (current) => current.copyWith(hasAudio: true, clearAudioError: true),
        );

        final bytes = await _audio.waitForSessionFileBytes(session);
        if (bytes == null) {
          return null;
        }

        final filePath = await repository.saveAudioFile(word, bytes);
        await repository.persistAudioPath(word, filePath);
        if (_audio.isDisposed) {
          return null;
        }

        _updateState(
          (current) => current.copyWith(audioUrl: filePath, hasAudio: true),
        );
        return filePath;
      }

      throw StateError('音频服务没有返回可播放的音频');
    } catch (error) {
      _updateState(
        (current) => current.copyWith(audioError: formatLearningError(error)),
      );
      return null;
    } finally {
      _updateState((current) => current.copyWith(isFetchingAudio: false));
    }
  }

  Future<void> _fetchExplanation(String word, String context) async {
    try {
      final repository = ref.read(wordRepositoryProvider);
      await consumeLearningContentStream(
        stream: repository.getWordExplanationStream(word, context),
        isDisposed: () => _audio.isDisposed,
        onContent: (appendedContent) {
          _updateState(
            (current) => current.copyWith(
              content: current.content + appendedContent,
              clearContentError: true,
            ),
          );
        },
      );
    } catch (error) {
      _updateState(
        (current) => current.copyWith(contentError: formatLearningError(error)),
      );
    } finally {
      _updateState((current) => current.copyWith(isFetchingContent: false));
    }
  }

  void _updateState(
    WordLearningState Function(WordLearningState current) update,
  ) {
    if (_audio.isDisposed) {
      return;
    }
    state = update(state);
  }
}
