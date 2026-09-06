import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';

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
  late LearningControllerSession<WordRepository> _session;

  @override
  WordLearningState build(WordLearningRequest request) {
    final repository = ref.watch(wordRepositoryProvider);
    final createPlayer = ref.watch(learningAudioPlayerFactoryProvider);
    late final LearningControllerSession<WordRepository> session;
    session = LearningControllerSession(
      repository: repository,
      audio: LearningAudioCoordinator(
        debugLabel: 'Word',
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
    unawaited(_loadData(request, session));
    return const WordLearningState();
  }

  /// 重建查询会话，取消旧请求并重新检查已完成的缓存。
  void retry() {
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> playAudio() => _session.audio.play(state.audioUrl);

  Future<void> _loadData(
    WordLearningRequest request,
    LearningControllerSession<WordRepository> session,
  ) async {
    try {
      await session.audio.initialize();
      if (session.isDisposed) return;

      final repository = session.repository;
      final result = await repository.getWordInfo(
        request.word,
        request.context,
        cancellation: session.cancellation,
      );
      if (session.isDisposed) {
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

      await session.audio.prepareLocalSource(result.audioUrl);
      if (session.isDisposed) {
        return;
      }

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(request.word, session));
      }

      if (result.hasCachedExplanation) {
        _updateState(
          session,
          (current) => current.copyWith(isFetchingContent: false),
        );
      } else {
        await _fetchExplanation(request.word, request.context, session);
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
    String word,
    LearningControllerSession<WordRepository> session,
  ) async {
    try {
      final repository = session.repository;
      await for (final result in repository.getPronunciationStream(
        word,
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
          word,
          bytes,
          result.format,
          cacheByVoice: result.cacheByVoice,
        );
        if (session.isDisposed) return null;
        await repository.persistAudioPath(word, filePath);
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

  Future<void> _fetchExplanation(
    String word,
    String context,
    LearningControllerSession<WordRepository> session,
  ) async {
    try {
      final repository = session.repository;
      await consumeLearningContentStream(
        stream: repository.getWordExplanationStream(
          word,
          context,
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
    LearningControllerSession<WordRepository> session,
    WordLearningState Function(WordLearningState current) update,
  ) {
    if (session.isDisposed) {
      return;
    }
    state = update(state);
  }
}
