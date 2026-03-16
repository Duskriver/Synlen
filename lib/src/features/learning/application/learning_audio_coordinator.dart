import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:synlen/src/features/learning/application/learning_streaming_audio_session.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

class LearningAudioCoordinator {
  final String debugLabel;
  final void Function(Object error)? onPlaybackError;
  final AudioPlayer _player = AudioPlayer();
  LearningStreamingAudioSession? _session;
  bool _isDisposed = false;
  bool _isInitialized = false;

  LearningAudioCoordinator({required this.debugLabel, this.onPlaybackError});

  bool get isDisposed => _isDisposed;

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) {
      return;
    }

    _isInitialized = true;
    try {
      await _player.setVolume(1.0);
      _player.playbackEventStream.listen(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (_isDisposed) {
            return;
          }
          debugPrint('$debugLabel audio playback stream error: $error');
          onPlaybackError?.call(error);
        },
      );
    } catch (error) {
      debugPrint('$debugLabel audio volume setup error: $error');
    }
  }

  Future<void> prepareLocalSource(String? audioUrl) async {
    if (_isDisposed || audioUrl == null || audioUrl.isEmpty) {
      return;
    }

    final file = File(audioUrl);
    if (await file.exists() && !_isDisposed) {
      await _player.setFilePath(audioUrl);
    }
  }

  Future<LearningStreamingAudioSession?> attachStreamingSource(
    AudioStreamResult result,
  ) async {
    if (_isDisposed) {
      return null;
    }

    _session?.dispose();
    final session = LearningStreamingAudioSession(
      byteStream: result.stream,
      format: result.format,
    );
    _session = session;
    await _player.setAudioSource(session.audioSource, preload: false);
    return _isDisposed ? null : session;
  }

  Future<List<int>?> waitForSessionFileBytes(
    LearningStreamingAudioSession session,
  ) async {
    final bytes = await session.waitForPlayableFileBytes();
    if (_isDisposed || _session != session) {
      return null;
    }
    return bytes;
  }

  Future<void> play(String? audioUrl) async {
    if (_isDisposed) {
      return;
    }

    try {
      if (_player.playing) {
        await _player.stop();
        await _player.seek(Duration.zero);
      }

      if (_player.audioSource == null) {
        if (audioUrl != null && audioUrl.isNotEmpty) {
          final file = File(audioUrl);
          if (await file.exists()) {
            await _player.setFilePath(audioUrl);
          }
        } else if (_session != null) {
          await _player.setAudioSource(_session!.audioSource);
        }
      }

      await _player.play();
    } catch (error) {
      debugPrint('$debugLabel audio play error: $error');
    }
  }

  void dispose() {
    _isDisposed = true;
    _session?.dispose();
    _player.dispose();
  }
}
