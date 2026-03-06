import 'dart:convert';
import 'package:dio/dio.dart';

class DeepSeekService {
  final Dio _dio = Dio();

  static const String _apiKey = 'REMOVED_BEFORE_OPEN_SOURCE';
  static const String _baseUrl = 'https://api.deepseek.com/chat/completions';
  static const String _model = 'deepseek-chat';

  /// 解释单词在特定上下文中的含义
  ///
  /// [word] 要解释的单词
  /// [context] 单词所在的上下文句子
  /// 返回解释文本，如果出错则返回 null
  Future<String?> explainWord(String word, String context) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': "请解释单词 '$word' 在上下文 '$context' 中的含义。提供定义和例句。",
            },
          ],
        },
      );

      if (response.statusCode == 200) {
        final choices = response.data['choices'] as List;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'];
        }
      }
      return null;
    } catch (e) {
      // print('DeepSeekService explainWord error: $e');
      return null;
    }
  }

  /// 解释单词在特定上下文中的含义（流式输出）
  ///
  /// [word] 要解释的单词
  /// [context] 单词所在的上下文句子
  /// 返回 Stream，包含生成的文本片段
  Stream<String> explainWordStream(String word, String context) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content':
                  "请解释单词 '$word' 在上下文 '$context' 中的含义。提供定义和例句。请使用 Markdown 格式。",
            },
          ],
          'stream': true,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        return;
      }

      final stream = response.data!.stream;
      final lineStream = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        if (trimmedLine == 'data: [DONE]') break;

        if (trimmedLine.startsWith('data: ')) {
          final jsonStr = trimmedLine.substring(6);
          try {
            final data = json.decode(jsonStr);
            final delta = data['choices'][0]['delta'];
            final content = delta['content'];
            if (content != null && content is String) {
              yield content;
            }
          } catch (e) {
            // 解析 JSON 出错，跳过
          }
        }
      }
    } catch (e) {
      // 错误处理
    }
  }

  /// 分析句子的语法和成分
  ///
  /// [sentence] 要分析的句子
  /// 返回分析文本，如果出错则返回 null
  Future<String?> analyzeSentence(String sentence) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {'role': 'user', 'content': "分析句子 '$sentence' 的语法和成分。请像英语老师一样解释。"},
          ],
        },
      );

      if (response.statusCode == 200) {
        final choices = response.data['choices'] as List;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 分析句子的语法和成分（流式输出）
  ///
  /// [sentence] 要分析的句子
  /// 返回 Stream，包含生成的文本片段
  Stream<String> analyzeSentenceStream(String sentence) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': "分析句子 '$sentence' 的语法和成分。请像英语老师一样解释。请使用 Markdown 格式。",
            },
          ],
          'stream': true,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        return;
      }

      final stream = response.data!.stream;
      final lineStream = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        if (trimmedLine == 'data: [DONE]') break;

        if (trimmedLine.startsWith('data: ')) {
          final jsonStr = trimmedLine.substring(6);
          try {
            final data = json.decode(jsonStr);
            final delta = data['choices'][0]['delta'];
            final content = delta['content'];
            if (content != null && content is String) {
              yield content;
            }
          } catch (e) {
            // 解析 JSON 出错，跳过
          }
        }
      }
    } catch (e) {
      // 错误处理
    }
  }
}
