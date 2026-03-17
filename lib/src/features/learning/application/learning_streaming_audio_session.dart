import 'dart:async';
import 'dart:typed_data';

import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

class LearningStreamingAudioSession {
  final AudioFormat format;
  final String? playbackUri;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;
  final Stream<List<int>> _byteStream;
  final List<Uint8List> _chunks = <Uint8List>[];
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  final Completer<void> _doneCompleter = Completer<void>();
  StreamSubscription<List<int>>? _subscription;
  Completer<void>? _chunkCompleter;
  Object? _error;
  StackTrace? _stackTrace;
  bool _isFinished = false;
  bool _isDisposed = false;

  LearningStreamingAudioSession._({
    required this.format,
    required this.playbackUri,
    required this.sampleRate,
    required this.numChannels,
    required this.bitsPerSample,
    required Stream<List<int>> byteStream,
  }) : _byteStream = byteStream {
    _listen();
  }

  factory LearningStreamingAudioSession({required AudioStreamResult result}) {
    return LearningStreamingAudioSession._(
      byteStream: result.stream,
      format: result.format,
      playbackUri: result.playbackUri,
      sampleRate: result.sampleRate ?? 24000,
      numChannels: result.numChannels ?? 1,
      bitsPerSample: result.bitsPerSample ?? 16,
    );
  }

  bool get supportsStreamingPlayback => format == AudioFormat.pcm;
  bool get hasImmediatePlayback =>
      supportsStreamingPlayback || playbackUri != null;
  Future<void> get done => _doneCompleter.future;

  Future<List<int>> waitForPlayableFileBytes() async {
    await done;
    return List<int>.from(_buffer.toBytes());
  }

  Stream<Uint8List> streamFromStart() async* {
    var index = 0;

    while (true) {
      while (index < _chunks.length) {
        yield _chunks[index];
        index++;
      }

      if (_error != null) {
        Error.throwWithStackTrace(_error!, _stackTrace!);
      }

      if (_isFinished) {
        return;
      }

      final waiter = _chunkCompleter ??= Completer<void>();
      await waiter.future;
    }
  }

  void _listen() {
    _subscription = _byteStream.listen(
      (chunk) {
        if (_isDisposed) {
          return;
        }

        final bytes = Uint8List.fromList(chunk);
        if (bytes.isEmpty) {
          return;
        }
        _chunks.add(bytes);
        _buffer.add(bytes);
        _chunkCompleter?.complete();
        _chunkCompleter = null;
      },
      onDone: () {
        _isFinished = true;
        _chunkCompleter?.complete();
        _chunkCompleter = null;
        if (!_doneCompleter.isCompleted) {
          _doneCompleter.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _error = error;
        _stackTrace = stackTrace;
        _isFinished = true;
        _chunkCompleter?.complete();
        _chunkCompleter = null;
        if (!_doneCompleter.isCompleted) {
          _doneCompleter.completeError(error, stackTrace);
        }
      },
      cancelOnError: true,
    );
  }

  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    _subscription = null;
    _isFinished = true;
    _chunkCompleter?.complete();
    _chunkCompleter = null;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}
