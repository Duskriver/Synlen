import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart';

abstract class LearningAudioPlayer {
  bool get isStopped;

  Future<void> openPlayer();

  Future<void> closePlayer();

  Future<void> setVolume(double volume);

  Future<void> startPlayer({
    required Codec codec,
    required String fromURI,
    required int numChannels,
  });

  Future<void> startPlayerFromStream({
    required Codec codec,
    required bool interleaved,
    required int numChannels,
    required int sampleRate,
    required int bufferSize,
  });

  Future<void> feedUint8FromStream(Uint8List data);

  Future<void> stopPlayer();
}

class FlutterSoundLearningAudioPlayer implements LearningAudioPlayer {
  FlutterSoundLearningAudioPlayer({Level logLevel = Level.error})
    : _player = FlutterSoundPlayer(logLevel: logLevel);

  final FlutterSoundPlayer _player;

  @override
  bool get isStopped => _player.isStopped;

  @override
  Future<void> closePlayer() => _player.closePlayer();

  @override
  Future<void> feedUint8FromStream(Uint8List data) {
    return _player.feedUint8FromStream(data);
  }

  @override
  Future<void> openPlayer() => _player.openPlayer();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> startPlayer({
    required Codec codec,
    required String fromURI,
    required int numChannels,
  }) {
    return _player.startPlayer(
      codec: codec,
      fromURI: fromURI,
      numChannels: numChannels,
    );
  }

  @override
  Future<void> startPlayerFromStream({
    required Codec codec,
    required bool interleaved,
    required int numChannels,
    required int sampleRate,
    required int bufferSize,
  }) {
    return _player.startPlayerFromStream(
      codec: codec,
      interleaved: interleaved,
      numChannels: numChannels,
      sampleRate: sampleRate,
      bufferSize: bufferSize,
    );
  }

  @override
  Future<void> stopPlayer() => _player.stopPlayer();
}
