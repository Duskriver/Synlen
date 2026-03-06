class WavHeaderUtil {
  /// 生成 WAV 头部 (PCM 格式)
  static List<int> generateWavHeader(
    int dataLength,
    int sampleRate,
    int channels,
    int bitsPerSample,
  ) {
    final header = List<int>.filled(44, 0);
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);

    // RIFF
    header[0] = 0x52; header[1] = 0x49; header[2] = 0x46; header[3] = 0x46;
    // ChunkSize (对于流式，设为一个较大的占位值)
    final chunkSize = dataLength > 0 ? dataLength + 36 : 0x7FFFFFFF;
    header[4] = chunkSize & 0xFF;
    header[5] = (chunkSize >> 8) & 0xFF;
    header[6] = (chunkSize >> 16) & 0xFF;
    header[7] = (chunkSize >> 24) & 0xFF;
    // WAVE
    header[8] = 0x57; header[9] = 0x41; header[10] = 0x56; header[11] = 0x45;
    // fmt 
    header[12] = 0x66; header[13] = 0x6D; header[14] = 0x74; header[15] = 0x20;
    header[16] = 16; // Subchunk1Size
    header[20] = 1;  // PCM = 1
    header[22] = channels;
    header[24] = sampleRate & 0xFF;
    header[25] = (sampleRate >> 8) & 0xFF;
    header[26] = (sampleRate >> 16) & 0xFF;
    header[27] = (sampleRate >> 24) & 0xFF;
    header[28] = byteRate & 0xFF;
    header[29] = (byteRate >> 8) & 0xFF;
    header[30] = (byteRate >> 16) & 0xFF;
    header[31] = (byteRate >> 24) & 0xFF;
    header[32] = blockAlign;
    header[34] = bitsPerSample;
    // data
    header[36] = 0x64; header[37] = 0x61; header[38] = 0x74; header[39] = 0x61;
    final dataSize = dataLength > 0 ? dataLength : 0x7FFFFFFF;
    header[40] = dataSize & 0xFF;
    header[41] = (dataSize >> 8) & 0xFF;
    header[42] = (dataSize >> 16) & 0xFF;
    header[43] = (dataSize >> 24) & 0xFF;
    
    return header;
  }
}
