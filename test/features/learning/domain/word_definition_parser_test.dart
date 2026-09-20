import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/domain/word_definition_parser.dart';

import '../word_definition_fixture.dart';

void main() {
  test('按记录发布不可变快照，简义先到且保留被点击词形音标', () {
    final parser = WordDefinitionParser();
    final summary = parser.addLine(wordSummaryRecord);
    expect(summary.summary!.lemma, 'sort');
    expect(summary.summary!.phonetic, '/ˈsɔːrtɪd/');
    expect(summary.summary!.partOfSpeech, 'verb');
    expect(summary.summary!.definitionEn, 'put things into groups');
    expect(summary.summary!.definitionZh, '分类');
    expect(summary.explanation, isNull);
    expect(summary.synonyms, isNull);
    expect(summary.formation, isNull);
    expect(summary.isComplete, isFalse);

    final explanation = parser.addLine(wordExplanationRecord);
    expect(explanation.explanation, contains('sorted'));
    final synonyms = parser.addLine(wordSynonymsRecord);
    expect(synonyms.synonyms!.single.word, 'classify');
    expect(synonyms.synonyms!.single.meaning, '分类');
    expect(synonyms.synonyms!.single.distinction, contains('标准'));
    expect(() => synonyms.synonyms!.clear(), throwsUnsupportedError);
    parser.addLine(wordFormationRecord);
    expect(parser.finish().isComplete, isTrue);
    expect(summary.explanation, isNull);
    expect(explanation.synonyms, isNull);
  });

  test('区分尚未生成与无可靠音标、近义词、构词', () {
    final summary = jsonDecode(wordSummaryRecord) as Map<String, dynamic>;
    summary['phonetic'] = null;
    final definition = WordDefinitionParser.parse(
      '${jsonEncode(summary)}\n$wordExplanationRecord'
      '{"type":"synonyms","items":[]}\n'
      '{"type":"formation","text":""}',
    );
    expect(definition.summary!.phonetic, isNull);
    expect(definition.synonyms, isEmpty);
    expect(definition.formation, isEmpty);
    expect(definition.isComplete, isTrue);
  });

  test('完整文档接受 CRLF、空白行、字符串转义及无末尾换行', () {
    final explanation = jsonEncode({
      'type': 'explanation',
      'text': '他说“sort”。\n下一行解释。',
    });
    final content = [
      wordSummaryRecord.trim(),
      '',
      explanation,
      wordSynonymsRecord.trim(),
      wordFormationRecord.trim(),
    ].join('\r\n');
    expect(
      WordDefinitionParser.parse(content).explanation,
      '他说“sort”。\n下一行解释。',
    );
  });

  final invalidDocuments = {
    '缺少记录': wordSummaryRecord,
    '重复记录': '$wordSummaryRecord$wordSummaryRecord',
    '顺序错误': '$wordSummaryRecord$wordSynonymsRecord',
    '多余记录': '$wordDefinitionContent$wordFormationRecord',
    '未知类型': '{"type":"unknown"}',
    'JSON 损坏': '{invalid}',
    '非对象记录': '[]',
    '代码围栏': '```json\n$wordDefinitionContent```',
    '缺少简义字段': '{"type":"summary","lemma":"sort"}',
    '空简义': wordSummaryRecord.replaceFirst('"分类"', '" "'),
    '简义类型错误': wordSummaryRecord.replaceFirst('"分类"', '42'),
    '音标类型错误': wordSummaryRecord.replaceFirst('"/ˈsɔːrtɪd/"', '42'),
    '空解释': '$wordSummaryRecord{"type":"explanation","text":""}',
    '近义词不是列表':
        '$wordSummaryRecord$wordExplanationRecord{"type":"synonyms","items":{}}',
    '近义词缺少区分':
        '$wordSummaryRecord$wordExplanationRecord'
        '{"type":"synonyms","items":[{"word":"classify","meaning":"分类"}]}',
    '构词类型错误':
        '$wordSummaryRecord$wordExplanationRecord$wordSynonymsRecord'
        '{"type":"formation","text":null}',
  };
  for (final entry in invalidDocuments.entries) {
    test('${entry.key} 拒绝作为完整释义', () {
      expect(
        () => WordDefinitionParser.parse(entry.value),
        throwsFormatException,
      );
    });
  }

  test('无效后续记录不改变已验证快照或消费顺序', () {
    final parser = WordDefinitionParser();
    parser.addLine(wordSummaryRecord);
    expect(() => parser.addLine(wordSynonymsRecord), throwsFormatException);
    final definition = parser.addLine(wordExplanationRecord);
    expect(definition.summary!.lemma, 'sort');
    expect(definition.explanation, contains('sorted'));
  });
}
