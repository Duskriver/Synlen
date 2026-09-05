import 'package:dio/dio.dart';
import 'learning_http_request.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

class FreeDictionaryService {
  FreeDictionaryService({required this.dio});

  final Dio dio;

  /// 获取单词发音 URL
  ///
  /// [word] 要查询的单词
  /// 未找到或请求失败返回 null；查询取消向调用方传播。
  Future<String?> getPronunciationUrl(
    String word, {
    LearningCancellation? cancellation,
  }) async {
    final request = LearningHttpRequest(cancellation);
    try {
      cancellation?.throwIfCancelled();
      final response = await dio.get(
        'https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word)}',
        cancelToken: request.cancelToken,
      );

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> entries = response.data;

        for (var entry in entries) {
          final List<dynamic>? phonetics = entry['phonetics'];
          if (phonetics != null) {
            for (var phonetic in phonetics) {
              var audio = phonetic['audio'];
              if (audio != null && audio is String && audio.isNotEmpty) {
                // 确保使用 https 协议，并处理 protocol-relative 链接
                if (audio.startsWith('//')) {
                  audio = 'https:$audio';
                } else if (audio.startsWith('http:')) {
                  audio = audio.replaceFirst('http:', 'https:');
                }
                return audio;
              }
            }
          }
        }
      }
      return null;
    } catch (e) {
      cancellation?.throwIfCancelled();
      return null;
    } finally {
      request.dispose();
    }
  }

  /// 根据 API 文档获取单词的详细词典条目
  ///
  /// [word] 要查询的单词
  /// [language] 语言代码，默认为 'en'
  Future<List<dynamic>?> getWordEntries(
    String word, {
    String language = 'en',
  }) async {
    try {
      final response = await dio.get(
        'https://api.dictionaryapi.dev/api/v2/entries/$language/$word',
      );

      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
