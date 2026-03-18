import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:synlen/src/features/learning/domain/aliyun_tts_voice.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';

class AliyunTTSService {
  AliyunTTSService({String Function()? readVoiceParam})
    : _readVoiceParam =
          readVoiceParam ?? (() => AliyunTtsVoice.defaultVoice.voiceParam);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final String Function() _readVoiceParam;
  static const String _apiKey = 'sk-2b1f34fb5c524d7a914e1d349bd46b04';
  static const String _url =
      'https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation';
  static const String _model = 'qwen3-tts-flash';

  String get currentVoiceParam => _readVoiceParam();

  /// 生成并流式输出语音音频
  ///
  /// [text] 要转换的文本
  /// 返回音频字节流 [Stream<List<int>>]
  Stream<List<int>> generateAudioStream(String text) async* {
    try {
      final voice = currentVoiceParam;
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
          'input': {'text': text, 'voice': voice, 'language_type': 'English'},
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

            // 阿里云 TTS 音频数据位于 output.audio.data，内容为 Base64 编码的 PCM
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
}
