import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
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

  /// 单词解释的固定输出契约：四节中文小节，标题固定以便 UI 稳定解析展示。
  /// 修改 prompt 时必须同步递增数据库层的学习缓存版本号使旧缓存失效。
  String _wordPrompt(String word, String context) =>
      '请严格按以下四节回答，每节以固定标题开头，除四节外不输出任何内容：\n'
      '## 音标\n'
      '（音标、词性及常见变形）\n'
      '## 直译\n'
      '（单词的本义翻译）\n'
      '## 常见用法\n'
      '（常见搭配与用法，至少一个英文例句及中文翻译）\n'
      '## 句中含义\n'
      '（结合上下文解释单词在句中的含义）\n'
      '单词：$word\n'
      '上下文：$context';

  /// 句子分析的固定输出契约：原句由本地直接展示，模型只负责翻译与语法分析。
  String _sentencePrompt(String sentence) =>
      '请严格按以下两节回答，每节以固定标题开头，不要重复原句，除两节外不输出任何内容：\n'
      '## 翻译\n'
      '（整句的中文翻译）\n'
      '## 语法分析\n'
      '（讲解句子结构与成分）\n'
      "句子：'$sentence'";

  /// 解释单词；只有完整成功的响应才正常结束，残文不得作为缓存提交。
  Stream<String> explainWordStream(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) => _complete(_wordPrompt(word, context), cancellation);

  /// 分析句子；取消订阅会取消正在等待响应头或正文的请求。
  Stream<String> analyzeSentenceStream(
    String sentence, {
    LearningCancellation? cancellation,
  }) => _complete(_sentencePrompt(sentence), cancellation);

  /// 校验密钥连通性：GET /models 不消耗 tokens，只验证密钥有效与网络可达。
  /// 401 表示密钥无效，其余异常由调用方归类为网络/服务问题。
  Future<void> verifyApiKey(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const LearningException(LearningErrorCode.noDeepSeekApiKey);
    }
    await _dio.get<void>(
      'https://api.deepseek.com/models',
      options: Options(
        headers: {'Authorization': 'Bearer $key'},
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
  }

  Stream<String> _complete(String prompt, LearningCancellation? cancellation) {
    final cancelToken = CancelToken();
    StreamIterator<String>? lines;
    Timer? deadline;
    void Function()? unregister;
    var cancelled = false;
    late final StreamController<String> output;

    Future<void> cancel() async {
      cancelled = true;
      deadline?.cancel();
      unregister?.call();
      cancelToken.cancel();
      await lines?.cancel();
    }

    void fail(Object error, [StackTrace? stackTrace]) {
      if (cancelled || output.isClosed) return;
      // 弹窗销毁触发的取消发生时流已无监听者，此时再投递错误会成为
      // 无人处理的孤儿错误；仅在仍有监听时投递。
      if (output.hasListener) {
        output.addError(
          error is LearningException || error is LearningCancelled
              ? error
              : LearningException(LearningErrorCode.requestFailed, error),
          stackTrace,
        );
      }
      unawaited(output.close());
      unawaited(cancel());
    }

    Future<void> run() async {
      unregister = cancellation?.onCancel(
        () => fail(const LearningCancelled()),
      );
      if (cancelled) return;
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
        unregister?.call();
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
