enum AudioFormat { mp3, wav, pcm }

class AudioStreamResult {
  final Stream<List<int>> stream;
  final AudioFormat format;
  final bool cacheByVoice;
  final String? playbackUri;
  final int? sampleRate;
  final int? numChannels;
  final int? bitsPerSample;

  AudioStreamResult({
    required this.stream,
    required this.format,
    this.cacheByVoice = false,
    this.playbackUri,
    this.sampleRate,
    this.numChannels,
    this.bitsPerSample,
  });
}
