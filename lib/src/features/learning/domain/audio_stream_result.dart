enum AudioFormat { mp3, wav, pcm }

class AudioStreamResult {
  final Stream<List<int>> stream;
  final AudioFormat format;

  AudioStreamResult({required this.stream, required this.format});
}
