// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:synlen/src/core/utils/wav_header_util.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

/// Shared streaming audio session used by learning flows.
///
/// It allows `just_audio` to start playback before the full audio payload has
/// arrived, while still buffering bytes for final persistence.
class LearningStreamingAudioSession {
  final AudioFormat format;
  final _StreamingAudioSource _audioSource;

  LearningStreamingAudioSession._(this._audioSource, this.format);

  factory LearningStreamingAudioSession({
    required Stream<List<int>> byteStream,
    required AudioFormat format,
  }) {
    return LearningStreamingAudioSession._(
      _StreamingAudioSource(byteStream, format),
      format,
    );
  }

  StreamAudioSource get audioSource => _audioSource;

  Future<List<int>> waitForPlayableFileBytes() async {
    await _audioSource.done;

    if (format == AudioFormat.pcm) {
      final pcmBytes = _audioSource.pcmBytes;
      final header = WavHeaderUtil.generateWavHeader(
        pcmBytes.length,
        24000,
        1,
        16,
      );
      return [...header, ...pcmBytes];
    }

    return List<int>.from(_audioSource.bytes);
  }

  void dispose() {
    _audioSource.dispose();
  }
}

class _StreamingAudioSource extends StreamAudioSource {
  final Stream<List<int>> _byteStream;
  final AudioFormat _format;
  final List<int> _buffer = [];
  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast();
  final Completer<void> _doneCompleter = Completer<void>();
  StreamSubscription<List<int>>? _subscription;
  bool _isFinished = false;

  _StreamingAudioSource(this._byteStream, this._format) {
    if (_format == AudioFormat.pcm) {
      _buffer.addAll(WavHeaderUtil.generateWavHeader(0, 24000, 1, 16));
    }
    _init();
  }

  List<int> get bytes => _buffer;

  List<int> get pcmBytes {
    if (_format == AudioFormat.pcm && _buffer.length >= 44) {
      return _buffer.sublist(44);
    }
    return _buffer;
  }

  Future<void> get done => _doneCompleter.future;

  void _init() {
    _subscription = _byteStream.listen(
      (chunk) {
        _buffer.addAll(chunk);
        if (!_controller.isClosed) {
          _controller.add(chunk);
        }
      },
      onDone: () {
        _isFinished = true;
        if (!_doneCompleter.isCompleted) {
          _doneCompleter.complete();
        }
        if (!_controller.isClosed) {
          _controller.close();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _isFinished = true;
        if (!_doneCompleter.isCompleted) {
          _doneCompleter.completeError(error, stackTrace);
        }
        if (!_controller.isClosed) {
          _controller.addError(error, stackTrace);
          _controller.close();
        }
      },
      cancelOnError: true,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _isFinished = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;

    return StreamAudioResponse(
      sourceLength: _isFinished ? _buffer.length : null,
      contentLength: _isFinished ? _buffer.length - start : null,
      offset: start,
      stream: _streamFrom(start),
      contentType: _format == AudioFormat.mp3 ? 'audio/mpeg' : 'audio/wav',
    );
  }

  Stream<List<int>> _streamFrom(int start) async* {
    if (start < _buffer.length) {
      yield _buffer.sublist(start);
    }

    if (!_isFinished) {
      await for (final chunk in _controller.stream) {
        yield chunk;
      }
    }
  }
}
