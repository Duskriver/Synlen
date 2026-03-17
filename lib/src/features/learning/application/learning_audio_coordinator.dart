import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';
import 'package:synlen/src/features/learning/application/learning_pcm_fade.dart';
import 'package:synlen/src/features/learning/application/learning_streaming_audio_session.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

class LearningAudioCoordinator {
  static const int _pcmFeedChunkSize = 8192;
  static const Duration _pcmFadeInDuration = Duration(milliseconds: 8);
  static const Duration _pcmFadeOutDuration = Duration(milliseconds: 8);

  final String debugLabel;
  final void Function(Object error)? onPlaybackError;
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.error);
  LearningStreamingAudioSession? _session;
  LearningPcmFade? _pcmFade;
  bool _isDisposed = false;
  bool _isInitialized = false;
  int _playbackToken = 0;

  LearningAudioCoordinator({required this.debugLabel, this.onPlaybackError});

  bool get isDisposed => _isDisposed;

  Future<void> initialize() async {
    if (_isInitialized || _isDisposed) {
      return;
    }

    _isInitialized = true;
    try {
      await _player.openPlayer();
      await _player.setVolume(1.0);
    } catch (error) {
      debugPrint('$debugLabel audio player init error: $error');
      onPlaybackError?.call(error);
    }
  }

  Future<void> prepareLocalSource(String? audioUrl) async {
    if (_isDisposed || audioUrl == null || audioUrl.isEmpty) {
      return;
    }

    if (_isRemoteUri(audioUrl)) {
      return;
    }

    final file = File(audioUrl);
    if (!await file.exists() && !_isDisposed) {
      throw FileSystemException('音频文件不存在', audioUrl);
    }
  }

  Future<LearningStreamingAudioSession?> attachStreamingSource(
    AudioStreamResult result,
  ) async {
    if (_isDisposed) {
      return null;
    }

    _session?.dispose();
    final session = LearningStreamingAudioSession(result: result);
    _session = session;
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

    final token = ++_playbackToken;

    try {
      await _stopPlayback();
      if (_isDisposed || token != _playbackToken) {
        return;
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        if (_isRemoteUri(audioUrl)) {
          await _playRemoteSource(audioUrl);
          return;
        }

        final file = File(audioUrl);
        if (await file.exists()) {
          await _playLocalSource(audioUrl, token);
          return;
        }
      }

      final session = _session;
      if (session != null && session.playbackUri != null) {
        await _playRemoteSource(session.playbackUri!);
        return;
      }

      if (session != null && session.supportsStreamingPlayback) {
        await _playPcmStream(
          byteStream: session.streamFromStart(),
          sampleRate: session.sampleRate,
          numChannels: session.numChannels,
          bitsPerSample: session.bitsPerSample,
          token: token,
        );
      }
    } catch (error) {
      debugPrint('$debugLabel audio play error: $error');
      onPlaybackError?.call(error);
    }
  }

  void dispose() {
    _isDisposed = true;
    _playbackToken++;
    _session?.dispose();
    unawaited(_stopPlayback());
    unawaited(_player.closePlayer());
  }

  Future<void> _playLocalSource(String audioUrl, int token) async {
    final codec = _codecForPath(audioUrl);
    if (codec == Codec.pcm16) {
      final bytes = await File(audioUrl).readAsBytes();
      await _playPcmStream(
        byteStream: Stream<Uint8List>.value(bytes),
        sampleRate: 24000,
        numChannels: 1,
        bitsPerSample: 16,
        token: token,
      );
      return;
    }

    await _player.startPlayer(codec: codec, fromURI: audioUrl, numChannels: 1);
  }

  Future<void> _playRemoteSource(String audioUrl) {
    return _player.startPlayer(
      codec: _codecForPath(audioUrl),
      fromURI: audioUrl,
      numChannels: 1,
    );
  }

  Future<void> _playPcmStream({
    required Stream<List<int>> byteStream,
    required int sampleRate,
    required int numChannels,
    required int bitsPerSample,
    required int token,
  }) async {
    if (bitsPerSample != 16) {
      throw UnsupportedError('仅支持 16-bit PCM 播放');
    }

    final frameSize = numChannels * (bitsPerSample ~/ 8);
    _pcmFade = LearningPcmFade(
      numChannels: numChannels,
      sampleRate: sampleRate,
      fadeInDuration: _pcmFadeInDuration,
      fadeOutDuration: _pcmFadeOutDuration,
    );

    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: true,
      numChannels: numChannels,
      sampleRate: sampleRate,
      bufferSize: _pcmFeedChunkSize,
    );

    final pending = BytesBuilder(copy: false);
    await for (final chunk in byteStream) {
      if (_isDisposed || token != _playbackToken) {
        return;
      }

      pending.add(chunk);
      final bytes = pending.takeBytes();
      final playableLength = bytes.length - (bytes.length % frameSize);
      if (playableLength > 0) {
        await _feedPcmBytes(
          Uint8List.sublistView(bytes, 0, playableLength),
          frameSize,
          token,
        );
      }

      if (playableLength < bytes.length) {
        pending.add(Uint8List.sublistView(bytes, playableLength));
      }
    }
  }

  Future<void> _feedPcmBytes(Uint8List bytes, int frameSize, int token) async {
    final chunkSize = (_pcmFeedChunkSize ~/ frameSize) * frameSize;
    var offset = 0;

    while (offset < bytes.length && !_isDisposed && token == _playbackToken) {
      final end = (offset + chunkSize) > bytes.length
          ? bytes.length
          : offset + chunkSize;
      final rawChunk = Uint8List.sublistView(bytes, offset, end);
      final fadedChunk = _pcmFade?.applyFadeIn(rawChunk) ?? rawChunk;
      await _player.feedUint8FromStream(fadedChunk);
      offset = end;
    }
  }

  Future<void> _stopPlayback() async {
    if (_isInitialized && !_player.isStopped) {
      final fadeOutTail = _pcmFade?.buildFadeOutTail() ?? Uint8List(0);
      if (fadeOutTail.isNotEmpty) {
        await _player.feedUint8FromStream(fadeOutTail);
      }
      await _player.stopPlayer();
    }
    _pcmFade = null;
  }

  Codec _codecForPath(String path) {
    final uri = Uri.tryParse(path);
    final normalizedPath = uri?.path.isNotEmpty == true ? uri!.path : path;
    final lowerPath = normalizedPath.toLowerCase();
    if (lowerPath.endsWith('.mp3')) {
      return Codec.mp3;
    }
    if (lowerPath.endsWith('.pcm')) {
      return Codec.pcm16;
    }
    return Codec.pcm16WAV;
  }

  bool _isRemoteUri(String path) {
    final uri = Uri.tryParse(path);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority;
  }
}
