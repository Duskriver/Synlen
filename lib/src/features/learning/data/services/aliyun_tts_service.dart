import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';

import 'package:synlen/src/core/utils/wav_header_util.dart';

class AliyunTTSService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  static const String _apiKey = 'sk-2b1f34fb5c524d7a914e1d349bd46b04';
  static const String _url =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  static const String _model = 'qwen3-tts-flash';

  /// 生成并流式输出语音音频
  ///
  /// [text] 要转换的文本
  /// 返回音频字节流 [Stream<List<int>>]
  Stream<List<int>> generateAudioStream(String text) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        _url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
            'X-DashScope-SSE': 'enable',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'input': {
            'text': text,
            'voice': 'Jennifer',
            'language_type': 'English',
          },
          'parameters': {
            // 阿里云该模型目前仅支持 pcm 格式输出，采样率为 24kHz
            'audio_format': 'pcm',
            'sample_rate': 24000,
          },
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        throw const LearningException('音频服务暂时不可用');
      }

      final stream = response.data!.stream;
      final lineStream = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      var hasAudio = false;

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.startsWith('data:')) {
          final jsonStr = trimmedLine.substring(5).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final data = json.decode(jsonStr);
            final output = data['output'];
            if (output == null) continue;

            // 1. 优先尝试从 audio_bin 提取 (二进制流)
            final audioBin = output['audio_bin'];
            if (audioBin != null && audioBin is String && audioBin.isNotEmpty) {
              hasAudio = true;
              yield base64.decode(audioBin);
              continue;
            }

            // 2. 尝试从 audio.data 中提取 Base64 音频
            final audioData = output['audio']?['data'];
            if (audioData != null &&
                audioData is String &&
                audioData.isNotEmpty) {
              hasAudio = true;
              yield base64.decode(audioData);
            }
          } catch (e) {
            debugPrint('Error parsing SSE line: $e');
          }
        }
      }
      if (!hasAudio) {
        throw const LearningException('音频服务没有返回音频数据');
      }
    } catch (e) {
      debugPrint('AliyunTTSService error: $e');
      if (e is LearningException) {
        rethrow;
      }
      throw LearningException('音频请求失败: $e');
    }
  }

  /// 保持向后兼容：生成音频并保存到文件 (添加 WAV 头部)
  Future<String?> generateAudio(String text) async {
    final bytes = <int>[];
    await for (final chunk in generateAudioStream(text)) {
      bytes.addAll(chunk);
    }

    if (bytes.isEmpty) return null;

    // 为 PCM 数据添加 WAV 头部
    final header = WavHeaderUtil.generateWavHeader(bytes.length, 24000, 1, 16);
    final fullBytes = [...header, ...bytes];

    final tempDir = await getTemporaryDirectory();
    final fileName =
        'tts_${DateTime.now().millisecondsSinceEpoch}_${text.hashCode}.wav';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(fullBytes);
    return file.path;
  }
}

