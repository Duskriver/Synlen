import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';

/// HTTP 客户端由调用方持有并释放；每次订阅拥有独立请求。
class DeepSeekService {
  DeepSeekService({
    FutureOr<String> Function()? readApiKey,
    required Dio dio,
    this.requestTimeout = const Duration(minutes: 2),
    this.idleTimeout = const Duration(seconds: 30),
  }) : _readApiKey = readApiKey ?? (() => ''),
       _dio = dio;

  final FutureOr<String> Function() _readApiKey;
  final Dio _dio;
  final Duration requestTimeout;
  final Duration idleTimeout;

  static const String _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const String _model = 'deepseek-v4-flash';

  /// 解释单词；只有完整成功的响应才正常结束，残文不得作为缓存提交。
  Stream<String> explainWordStream(String word, String context) =>
      _complete("优先显示$word的音标、词性及变形。然后解释单词 '$word' 在上下文 '$context' 中的含义。");

  /// 分析句子；取消订阅会取消正在等待响应头或正文的请求。
  Stream<String> analyzeSentenceStream(String sentence) =>
      _complete("优先显示原句及翻译，然后教我理解，最后分析它的语法和成分。'$sentence'");

  Stream<String> _complete(String prompt) {
    final cancelToken = CancelToken();
    StreamIterator<String>? lines;
    Timer? deadline;
    var cancelled = false;
    late final StreamController<String> output;

    Future<void> cancel() async {
      cancelled = true;
      deadline?.cancel();
      cancelToken.cancel();
      await lines?.cancel();
    }

    void fail(Object error, [StackTrace? stackTrace]) {
      if (cancelled || output.isClosed) return;
      output.addError(
        error is LearningException
            ? error
            : LearningException(LearningErrorCode.requestFailed, error),
        stackTrace,
      );
      unawaited(output.close());
      unawaited(cancel());
    }

    Future<void> run() async {
      deadline = Timer(requestTimeout, () {
        fail(TimeoutException('DeepSeek request exceeded its deadline'));
      });
      try {
        final apiKey = (await _readApiKey()).trim();
        if (cancelled) return;
        if (apiKey.isEmpty) {
          throw const LearningException(LearningErrorCode.noDeepSeekApiKey);
        }
        final response = await _dio.post<ResponseBody>(
          _baseUrl,
          cancelToken: cancelToken,
          options: Options(
            headers: {'Authorization': 'Bearer $apiKey'},
            contentType: Headers.jsonContentType,
            responseType: ResponseType.stream,
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: idleTimeout,
          ),
          data: {
            'model': _model,
            'thinking': {'type': 'disabled'},
            'max_tokens': 4096,
            'messages': [
              {
                'role': 'system',
                'content': '你是一位资深英语老师，你的目的是帮助用户学好英语，你不喜欢讲废话。使用markdown格式输出。',
              },
              {'role': 'user', 'content': prompt},
            ],
            'stream': true,
          },
        );
        if (cancelled) return;
        if (response.statusCode != 200 || response.data == null) {
          throw const LearningException(LearningErrorCode.serviceUnavailable);
        }
        lines = StreamIterator(
          response.data!.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(idleTimeout),
        );
        var hasContent = false;
        var stopped = false;
        var done = false;
        while (await lines!.moveNext()) {
          if (cancelled) return;
          final line = lines!.current;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload == '[DONE]') {
            done = true;
            break;
          }
          final event = jsonDecode(payload) as Map<String, dynamic>;
          final choices = event['choices'] as List<dynamic>;
          // 兼容仅含 usage 的事件，不将它视为完成标志。
          if (choices.isEmpty) continue;
          final choice = choices.single as Map<String, dynamic>;
          final reason = choice['finish_reason'];
          if (reason != null && reason != 'stop') {
            throw const LearningException(LearningErrorCode.requestFailed);
          }
          final delta = choice['delta'] as Map<String, dynamic>;
          final content = delta['content'];
          if (content != null && content is! String) {
            throw const FormatException('Invalid DeepSeek content');
          }
          if (content is String && content.isNotEmpty) {
            if (stopped) {
              throw const FormatException('Content after DeepSeek completion');
            }
            hasContent = hasContent || content.trim().isNotEmpty;
            output.add(content);
          }
          stopped = stopped || reason == 'stop';
        }
        if (cancelled) return;
        if (!done || !stopped) {
          throw const LearningException(LearningErrorCode.requestFailed);
        }
        if (!hasContent) {
          throw const LearningException(LearningErrorCode.emptyResult);
        }
        unawaited(output.close());
      } catch (error, stackTrace) {
        fail(error, stackTrace);
      } finally {
        deadline?.cancel();
        await lines?.cancel();
      }
    }

    output = StreamController<String>(
      onListen: () => unawaited(run()),
      onCancel: cancel,
    );
    return output.stream;
  }
}
