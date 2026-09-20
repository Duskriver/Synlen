import 'package:dio/dio.dart';
import 'learning_http_request.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

class FreeDictionaryService {
  FreeDictionaryService({required this.dio});

  final Dio dio;
  static const _requestTimeout = Duration(seconds: 2);

  /// 获取原词的有道美音 MP3；两秒内未完整下载或响应无效时返回 null。
  /// 查询取消向调用方传播，不触发 TTS 回退。
  Future<List<int>?> getPronunciationAudio(
    String word, {
    LearningCancellation? cancellation,
  }) async {
    final request = LearningHttpRequest(cancellation);
    try {
      cancellation?.throwIfCancelled();
      final response = await dio
          .get<List<int>>(
            Uri.https('dict.youdao.com', '/dictvoice', {
              'audio': word,
              'type': '2',
            }).toString(),
            cancelToken: request.cancelToken,
            options: Options(responseType: ResponseType.bytes),
          )
          .timeout(_requestTimeout);
      cancellation?.throwIfCancelled();
      final type = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      final bytes = response.data;
      if (response.statusCode == 200 &&
          (type == 'audio/mpeg' || type == 'audio/mp3') &&
          bytes != null &&
          bytes.isNotEmpty) {
        return bytes;
      }
      return null;
    } catch (e) {
      cancellation?.throwIfCancelled();
      return null;
    } finally {
      request.dispose();
    }
  }
}
