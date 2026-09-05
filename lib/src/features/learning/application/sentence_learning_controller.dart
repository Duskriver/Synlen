import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';

part 'sentence_learning_controller.g.dart';

typedef SentenceLearningState = LearningDetailState;

@riverpod
class SentenceLearningController extends _$SentenceLearningController {
  late LearningControllerSession<SentenceRepository> _session;

  @override
  SentenceLearningState build(String sentence) {
    final repository = ref.watch(sentenceRepositoryProvider);
    final createPlayer = ref.watch(learningAudioPlayerFactoryProvider);
    late final LearningControllerSession<SentenceRepository> session;
    session = LearningControllerSession(
      repository: repository,
      audio: LearningAudioCoordinator(
        debugLabel: 'Sentence',
        player: createPlayer(),
        onPlaybackError: (error) {
          _updateState(
            session,
            (current) => current.copyWith(audioError: error),
          );
        },
      ),
    );
    _session = session;
    ref.onDispose(session.dispose);
    unawaited(_loadData(sentence, session));
    return const SentenceLearningState();
  }

  Future<void> playAudio() => _session.audio.play(state.audioUrl);

  Future<void> _loadData(
    String sentence,
    LearningControllerSession<SentenceRepository> session,
  ) async {
    try {
      await session.audio.initialize();
      if (session.isDisposed) return;

      final repository = session.repository;
      final result = await repository.getSentenceInfo(
        sentence,
        cancellation: session.cancellation,
      );
      if (session.isDisposed) {
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

      await session.audio.prepareLocalSource(result.audioUrl);
      if (session.isDisposed) {
        return;
      }

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(sentence, session));
      }

      if (result.hasCachedAnalysis) {
        _updateState(
          session,
          (current) => current.copyWith(isFetchingContent: false),
        );
      } else {
        await _fetchAnalysis(sentence, session);
      }
    } catch (error) {
      _updateState(
        session,
        (current) => current.copyWith(
          isLoading: false,
          isFetchingContent: false,
          isFetchingAudio: false,
          contentError: error,
        ),
      );
    }
  }

  Future<String?> _fetchAndCacheAudio(
    String sentence,
    LearningControllerSession<SentenceRepository> session,
  ) async {
    try {
      final repository = session.repository;
      await for (final result in repository.getPronunciationStream(
        sentence,
        cancellation: session.cancellation,
      )) {
        final audioSession = await session.audio.attachStreamingSource(result);
        if (audioSession == null) {
          return null;
        }

        _updateState(
          session,
          (current) => current.copyWith(
            audioUrl: audioSession.playbackUri,
            hasAudio: audioSession.hasImmediatePlayback,
            clearAudioError: true,
          ),
        );

        final bytes = await session.audio.waitForSessionFileBytes(audioSession);
        if (bytes == null) {
          return null;
        }

        final filePath = await repository.saveAudioFile(
          sentence,
          bytes,
          result.format,
          cacheByVoice: result.cacheByVoice,
        );
        if (session.isDisposed) return null;
        await repository.persistAudioPath(sentence, filePath);
        if (session.isDisposed) {
          return null;
        }

        _updateState(
          session,
          (current) => current.copyWith(audioUrl: filePath, hasAudio: true),
        );
        return filePath;
      }

      throw const LearningException(LearningErrorCode.noPlayableAudio);
    } catch (error) {
      _updateState(session, (current) => current.copyWith(audioError: error));
      return null;
    } finally {
      _updateState(
        session,
        (current) => current.copyWith(isFetchingAudio: false),
      );
    }
  }

  Future<void> _fetchAnalysis(
    String sentence,
    LearningControllerSession<SentenceRepository> session,
  ) async {
    try {
      final repository = session.repository;
      await consumeLearningContentStream(
        stream: repository.getSentenceAnalysisStream(
          sentence,
          cancellation: session.cancellation,
        ),
        cancellation: session.cancellation,
        isDisposed: () => session.isDisposed,
        onContent: (appendedContent) {
          _updateState(
            session,
            (current) => current.copyWith(
              content: current.content + appendedContent,
              clearContentError: true,
            ),
          );
        },
      );
    } catch (error) {
      _updateState(session, (current) => current.copyWith(contentError: error));
    } finally {
      _updateState(
        session,
        (current) => current.copyWith(isFetchingContent: false),
      );
    }
  }

  void _updateState(
    LearningControllerSession<SentenceRepository> session,
    SentenceLearningState Function(SentenceLearningState current) update,
  ) {
    if (session.isDisposed) {
      return;
    }
    state = update(state);
  }
}
