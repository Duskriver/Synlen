import 'dart:math' as math;
import 'dart:typed_data';

class LearningPcmFade {
  final int numChannels;
  final int sampleRate;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  late final int _frameSize = numChannels * 2;
  late final int _fadeInTotalFrames = _frameCountFor(fadeInDuration);
  late final int _fadeOutTotalFrames = _frameCountFor(fadeOutDuration);
  int _fadeInProcessedFrames = 0;
  late final List<int> _lastFrameSamples = List<int>.filled(numChannels, 0);

  LearningPcmFade({
    required this.numChannels,
    required this.sampleRate,
    required this.fadeInDuration,
    required this.fadeOutDuration,
  });

  Uint8List applyFadeIn(Uint8List bytes) {
    if (bytes.isEmpty) {
      return bytes;
    }

    final frameCount = bytes.length ~/ _frameSize;
    if (frameCount == 0) {
      return bytes;
    }

    final remainingFadeFrames = _fadeInTotalFrames - _fadeInProcessedFrames;
    if (remainingFadeFrames <= 0) {
      _rememberLastFrame(bytes, frameCount);
      return bytes;
    }

    final mutableBytes = Uint8List.fromList(bytes);
    final byteData = ByteData.sublistView(mutableBytes);
    final framesToFade = math.min(frameCount, remainingFadeFrames);

    for (var frameIndex = 0; frameIndex < framesToFade; frameIndex++) {
      final gain =
          (_fadeInProcessedFrames + frameIndex + 1) / _fadeInTotalFrames;
      for (var channel = 0; channel < numChannels; channel++) {
        final sampleOffset = frameIndex * _frameSize + channel * 2;
        final sample = byteData.getInt16(sampleOffset, Endian.little);
        byteData.setInt16(
          sampleOffset,
          (sample * gain).round().clamp(-32768, 32767),
          Endian.little,
        );
      }
    }

    _fadeInProcessedFrames += framesToFade;
    _rememberLastFrame(mutableBytes, frameCount);
    return mutableBytes;
  }

  Uint8List buildFadeOutTail() {
    final hasNonZeroSample = _lastFrameSamples.any((sample) => sample != 0);
    if (!hasNonZeroSample) {
      return Uint8List(0);
    }

    final tailBytes = Uint8List(_fadeOutTotalFrames * _frameSize);
    final byteData = ByteData.sublistView(tailBytes);

    for (var frameIndex = 0; frameIndex < _fadeOutTotalFrames; frameIndex++) {
      final gain = (_fadeOutTotalFrames - frameIndex - 1) / _fadeOutTotalFrames;
      for (var channel = 0; channel < numChannels; channel++) {
        final sampleOffset = frameIndex * _frameSize + channel * 2;
        byteData.setInt16(
          sampleOffset,
          (_lastFrameSamples[channel] * gain).round().clamp(-32768, 32767),
          Endian.little,
        );
      }
    }

    return tailBytes;
  }

  int _frameCountFor(Duration duration) {
    final frames =
        (sampleRate * duration.inMicroseconds) ~/
        Duration.microsecondsPerSecond;
    return math.max(1, frames);
  }

  void _rememberLastFrame(Uint8List bytes, int frameCount) {
    final byteData = ByteData.sublistView(bytes);
    final lastFrameOffset = (frameCount - 1) * _frameSize;
    for (var channel = 0; channel < numChannels; channel++) {
      _lastFrameSamples[channel] = byteData.getInt16(
        lastFrameOffset + channel * 2,
        Endian.little,
      );
    }
  }
}
