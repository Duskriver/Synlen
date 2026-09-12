import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_controller_support.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/domain/learning_repository.dart';

part 'learning_controller.g.dart';

@riverpod
class LearningController extends _$LearningController {
  late LearningControllerSession<LearningRepository> _session;

  @override
  LearningDetailState build(LearningQuery query) {
    final repository = ref.watch(learningRepositoryProvider(query));
    final createPlayer = ref.watch(learningAudioPlayerFactoryProvider);
    late final LearningControllerSession<LearningRepository> session;
    session = LearningControllerSession(
      repository: repository,
      audio: LearningAudioCoordinator(
        debugLabel: switch (query) {
          WordLearningQuery() => 'Word',
          SentenceLearningQuery() => 'Sentence',
        },
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
    unawaited(_loadData(query, session));
    return const LearningDetailState();
  }

  /// 重建查询会话，取消旧请求并重新检查已完成的缓存。
  void retry() {
    if (ref.mounted) ref.invalidateSelf();
  }

  Future<void> playAudio() => _session.audio.play(state.audioUrl);

  Future<void> _loadData(
    LearningQuery query,
    LearningControllerSession<LearningRepository> session,
  ) async {
    try {
      await session.audio.initialize();
      if (session.isDisposed) return;

      final repository = session.repository;
      final result = await repository.getInfo(
        query,
        cancellation: session.cancellation,
      );
      if (session.isDisposed) {
        return;
      }

      state = LearningDetailState(
        isLoading: false,
        isFetchingContent: !result.hasCachedContent,
        isFetchingAudio: !result.hasCachedAudio,
        content: result.content ?? '',
        audioUrl: result.audioUrl,
        hasAudio: result.hasCachedAudio,
      );

      await session.audio.prepareLocalSource(result.audioUrl);
      if (session.isDisposed) {
        return;
      }

      if (!result.hasCachedAudio) {
        unawaited(_fetchAndCacheAudio(query, session));
      }

      if (result.hasCachedContent) {
        _updateState(
          session,
          (current) => current.copyWith(isFetchingContent: false),
        );
      } else {
        await _fetchContent(query, session);
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
    LearningQuery query,
    LearningControllerSession<LearningRepository> session,
  ) async {
    final target = query.target;
    try {
      final repository = session.repository;
      await for (final result in repository.getPronunciationStream(
        target,
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
          target,
          bytes,
          result.format,
          cacheByVoice: result.cacheByVoice,
        );
        if (session.isDisposed) return null;
        await repository.persistAudioPath(target, filePath);
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

  Future<void> _fetchContent(
    LearningQuery query,
    LearningControllerSession<LearningRepository> session,
  ) async {
    try {
      final repository = session.repository;
      await consumeLearningContentStream(
        stream: repository.getContentStream(
          query,
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
    LearningControllerSession<LearningRepository> session,
    LearningDetailState Function(LearningDetailState current) update,
  ) {
    if (session.isDisposed) {
      return;
    }
    state = update(state);
  }
}
