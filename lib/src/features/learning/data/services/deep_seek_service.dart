import 'dart:convert';
import 'package:dio/dio.dart';

class DeepSeekService {
  final Dio _dio = Dio();

  static const String _apiKey = 'sk-a01e451642ef4780bd7c701b3f2145bc';
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
              'content':
                  "请解释单词 '$word' 在上下文 '$context' 中的含义。请按以下 Markdown 格式输出：\n1. **音标**：提供美式和英式音标。\n2. **词性及变形**：指出当前词性及其它常见变形（如复数、时态等）。\n3. **上下文作用**：分析该单词在当前句子中的具体角色和用法。\n4. **中文定义**：简要说明。\n5. **例句**：提供一个简单、地道的例句。\n输出请保持简洁明了。",
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
              "role": "system",
              "content": "你是一位资深英语老师，你的目的是帮助用户学好英语，你不喜欢讲废话。使用markdown格式输出。",
            },
            {
              'role': 'user',
              'content':
                  "优先显示$word的音标、词性及变形。然后解释单词 '$word' 在上下文 '$context' 中的含义。",
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
            {
              'role': 'user',
              'content':
                  "分析句子 '$sentence'。请按以下 Markdown 格式输出：\n1. **整句翻译**：提供最自然、地道的中文翻译。\n2. **语法分析**：简明拆解主干成分及重点语法现象。\n3. **词汇亮点**：提取 1-2 个重点单词或短语简单解释。\n请像资深英语老师一样讲解，但要言简意赅，拒绝废话。\n最后你可以自由发挥一个段落",
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
              "role": "system",
              "content": "你是一位资深英语老师，你的目的是帮助用户学好英语，你不喜欢讲废话。使用markdown格式输出。",
            },
            {
              'role': 'user',
              'content': "优先显示原句及翻译，然后教我理解，最后分析它的语法和成分。'$sentence'",
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
