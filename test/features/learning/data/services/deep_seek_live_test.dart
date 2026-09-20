import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/domain/word_definition_parser.dart';

/// 真实 DeepSeek 接口的受控端到端验收。
///
/// 仅在设置 `SYNLEN_DEEPSEEK_KEY` 环境变量时运行，密钥不入库；
/// CI 与日常 `flutter test` 因变量缺失自动跳过。
void main() {
  final apiKey = Platform.environment['SYNLEN_DEEPSEEK_KEY']?.trim() ?? '';
  final skipReason = apiKey.isEmpty ? '未设置 SYNLEN_DEEPSEEK_KEY，跳过真实接口验收' : null;

  DeepSeekService service() =>
      DeepSeekService(dio: Dio(), readApiKey: () => apiKey);

  test(
    '单词解释流：模型可用且输出完整四条 NDJSON',
    () async {
      // 流按增量 delta 发出，必须无分隔符拼接。
      final sections = await service()
          .explainWordStream(
            'perseverance',
            'His perseverance finally paid off.',
          )
          .join();

      final definition = WordDefinitionParser.parse(sections);
      expect(definition.isComplete, isTrue);
      expect(definition.summary!.lemma, 'perseverance');
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: skipReason,
  );

  test(
    '句子分析流：输出翻译与语法分析两节且不回显原句',
    () async {
      const sentence =
          'The novel that she recommended last week has already sold out.';
      final sections = await service().analyzeSentenceStream(sentence).join();

      expect(sections, contains('## 翻译'));
      expect(sections, contains('## 语法分析'));
      expect(sections, isNot(contains('原句')), reason: '原句由本地展示，模型不应回显');
    },
    timeout: const Timeout(Duration(minutes: 3)),
    skip: skipReason,
  );
}
