import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';

part 'sentence_learning_controller.g.dart';

typedef SentenceLearningState = LearningDetailState;

@riverpod
class SentenceLearningController extends _$SentenceLearningController {
  late final LearningAudioCoordinator _audio;

  @override
  SentenceLearningState build(String sentence) {
    _audio = LearningAudioCoordinator(
      debugLabel: 'Sentence',
      onPlaybackError: (error) {
        _updateState(
          (current) => current.copyWith(audioError: formatLearningError(error)),
        );
      },
    );
    ref.onDispose(_audio.dispose);
    unawaited(_loadData(sentence));
    return const SentenceLearningState();
  }

  Future<void> playAudio() => _audio.play(state.audioUrl);

  Future<void> _loadData(String sentence) async {
    try {
      await _audio.initialize();

      final repository = ref.read(sentenceRepositoryProvider);
      final result = await repository.getSentenceInfo(sentence);
      if (_audio.isDisposed) {
        return;
      }

      state = SentenceLearningState(
        isLoading: false,
        isFetchingContent: !result.hasCachedAnalysis,
        isFetchingAudio: !result.hasCachedAudio,
        content: result.analysis ?? '',
        audioUrl: result.audioUrl,
        hasAudio: result.hasCachedAudio,
      );

      await _audio.prepareLocalSource(result.audioUrl);
      if (_audio.isDisposed) {
        return;
      }

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(sentence));
      }

      if (result.hasCachedAnalysis) {
        _updateState((current) => current.copyWith(isFetchingContent: false));
      } else {
        await _fetchAnalysis(sentence);
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

  Future<String?> _fetchAndCacheAudio(String sentence) async {
    try {
      final repository = ref.read(sentenceRepositoryProvider);
      await for (final result in repository.getPronunciationStream(sentence)) {
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

        final filePath = await repository.saveAudioFile(sentence, bytes);
        await repository.persistAudioPath(sentence, filePath);
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

  Future<void> _fetchAnalysis(String sentence) async {
    try {
      final repository = ref.read(sentenceRepositoryProvider);
      await consumeLearningContentStream(
        stream: repository.getSentenceAnalysisStream(sentence),
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
    SentenceLearningState Function(SentenceLearningState current) update,
  ) {
    if (_audio.isDisposed) {
      return;
    }
    state = update(state);
  }
}
