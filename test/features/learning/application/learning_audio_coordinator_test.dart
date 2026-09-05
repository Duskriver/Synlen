import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_audio_player.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';

class FakeLearningAudioPlayer implements LearningAudioPlayer {
  final List<String> startedUris = <String>[];
  final List<Uint8List> fedChunks = <Uint8List>[];
  Completer<void>? feedBlocker;
  int streamStartCount = 0;
  int stopCount = 0;
  bool _isStopped = true;

  @override
  bool get isStopped => _isStopped;

  @override
  Future<void> closePlayer() async {}

  @override
  Future<void> feedUint8FromStream(Uint8List data) async {
    fedChunks.add(Uint8List.fromList(data));
    final blocker = feedBlocker;
    if (blocker != null && !blocker.isCompleted) {
      await blocker.future;
    }
  }

  @override
  Future<void> openPlayer() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> startPlayer({
    required Codec codec,
    required String fromURI,
    required int numChannels,
  }) async {
    startedUris.add(fromURI);
    _isStopped = false;
  }

  @override
  Future<void> startPlayerFromStream({
    required Codec codec,
    required bool interleaved,
    required int numChannels,
    required int sampleRate,
    required int bufferSize,
  }) async {
    streamStartCount++;
    _isStopped = false;
  }

  @override
  Future<void> stopPlayer() async {
    stopCount++;
    _isStopped = true;
  }
}

class DeferredOpenPlayer extends FakeLearningAudioPlayer {
  final opened = Completer<void>();
  final closed = Completer<void>();
  int volumeCalls = 0;

  @override
  Future<void> openPlayer() => opened.future;

  @override
  Future<void> closePlayer() async => closed.complete();

  @override
  Future<void> setVolume(double volume) async => volumeCalls++;
}

void main() {
  group('LearningAudioCoordinator', () {
    test('初始化尚未结束时关闭，等待打开后释放且不再设置音量', () async {
      final player = DeferredOpenPlayer();
      final coordinator = LearningAudioCoordinator(
        debugLabel: 'test',
        player: player,
      );
      final initialized = coordinator.initialize();
      coordinator.dispose();
      coordinator.dispose();
      expect(player.closed.isCompleted, isFalse);
      player.opened.complete();
      await initialized;
      await player.closed.future.timeout(const Duration(seconds: 1));
      expect(player.volumeCalls, 0);
    });

    test('restarts the same remote source when play is tapped again', () async {
      final player = FakeLearningAudioPlayer();
      final coordinator = LearningAudioCoordinator(
        debugLabel: 'test',
        player: player,
      );

      await coordinator.initialize();
      await coordinator.play('https://example.com/audio.mp3');
      await coordinator.play('https://example.com/audio.mp3');

      expect(player.startedUris, <String>[
        'https://example.com/audio.mp3',
        'https://example.com/audio.mp3',
      ]);
      expect(player.stopCount, 1);
      coordinator.dispose();
    });

    test('buffers pcm before starting stream playback', () async {
      final player = FakeLearningAudioPlayer();
      final coordinator = LearningAudioCoordinator(
        debugLabel: 'test',
        player: player,
      );

      await coordinator.initialize();
      final controller = StreamController<List<int>>();
      final session = await coordinator.attachStreamingSource(
        AudioStreamResult(
          stream: controller.stream,
          format: AudioFormat.pcm,
          sampleRate: 24000,
          numChannels: 1,
          bitsPerSample: 16,
        ),
      );

      expect(session, isNotNull);
      final playFuture = coordinator.play(null);
      await Future<void>.delayed(Duration.zero);
      expect(player.streamStartCount, 0);

      controller.add(List<int>.filled(4096, 1));
      await Future<void>.delayed(Duration.zero);
      expect(player.streamStartCount, 0);

      controller.add(List<int>.filled(12288, 2));
      await controller.close();
      await playFuture;

      expect(player.streamStartCount, 1);
      expect(
        player.fedChunks.fold<int>(0, (sum, chunk) => sum + chunk.length),
        16384,
      );
      coordinator.dispose();
    });

    test(
      'restarts the same pcm session without attaching a new source',
      () async {
        final player = FakeLearningAudioPlayer();
        player.feedBlocker = Completer<void>();
        final coordinator = LearningAudioCoordinator(
          debugLabel: 'test',
          player: player,
        );

        await coordinator.initialize();
        await coordinator.attachStreamingSource(
          AudioStreamResult(
            stream: Stream<List<int>>.fromIterable(<List<int>>[
              List<int>.filled(20000, 3),
            ]),
            format: AudioFormat.pcm,
            sampleRate: 24000,
            numChannels: 1,
            bitsPerSample: 16,
          ),
        );

        final firstPlay = coordinator.play(null);
        await Future<void>.delayed(Duration.zero);
        final secondPlay = coordinator.play(null);
        await Future<void>.delayed(Duration.zero);
        player.feedBlocker!.complete();

        await Future.wait(<Future<void>>[firstPlay, secondPlay]);

        expect(player.streamStartCount, 2);
        expect(player.stopCount, 1);
        coordinator.dispose();
      },
    );
  });
}
