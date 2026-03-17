import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/application/learning_pcm_fade.dart';

void main() {
  group('LearningPcmFade', () {
    test('applies a short linear fade-in to initial pcm frames', () {
      final fade = LearningPcmFade(
        numChannels: 1,
        sampleRate: 1000,
        fadeInDuration: const Duration(milliseconds: 4),
        fadeOutDuration: const Duration(milliseconds: 4),
      );

      final bytes = _monoPcm16Bytes(const <int>[1000, 1000, 1000, 1000, 1000]);
      final faded = fade.applyFadeIn(bytes);

      expect(_readMonoPcm16(faded), <int>[250, 500, 750, 1000, 1000]);
    });

    test('builds a short fade-out tail from the latest pcm frame', () {
      final fade = LearningPcmFade(
        numChannels: 1,
        sampleRate: 1000,
        fadeInDuration: const Duration(milliseconds: 1),
        fadeOutDuration: const Duration(milliseconds: 4),
      );

      fade.applyFadeIn(_monoPcm16Bytes(const <int>[1000]));
      final tail = fade.buildFadeOutTail();

      expect(_readMonoPcm16(tail), <int>[750, 500, 250, 0]);
    });
  });
}

Uint8List _monoPcm16Bytes(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final byteData = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    byteData.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

List<int> _readMonoPcm16(Uint8List bytes) {
  final byteData = ByteData.sublistView(bytes);
  final sampleCount = bytes.length ~/ 2;
  return List<int>.generate(
    sampleCount,
    (index) => byteData.getInt16(index * 2, Endian.little),
  );
}
