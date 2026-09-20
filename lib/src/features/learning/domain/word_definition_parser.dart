import 'dart:convert';

import 'package:synlen/src/features/learning/domain/word_definition.dart';

/// 按固定顺序解析四条 NDJSON；无效记录抛出 FormatException，不改变已有快照。
class WordDefinitionParser {
  static const _sections = ['summary', 'explanation', 'synonyms', 'formation'];
  var _nextSection = 0;
  var _definition = const WordDefinition();

  WordDefinition addLine(String line) {
    final record = jsonDecode(line);
    if (record is! Map<String, dynamic> ||
        _nextSection >= _sections.length ||
        record['type'] != _sections[_nextSection]) {
      throw const FormatException('Invalid word definition record order');
    }

    final previous = _definition;
    _definition = switch (_sections[_nextSection]) {
      'summary' => WordDefinition(
        summary: WordSummary(
          lemma: _text(record, 'lemma'),
          phonetic: record['phonetic'] == null
              ? null
              : _text(record, 'phonetic'),
          partOfSpeech: _text(record, 'partOfSpeech'),
          definitionEn: _text(record, 'definitionEn'),
          definitionZh: _text(record, 'definitionZh'),
        ),
      ),
      'explanation' => WordDefinition(
        summary: previous.summary,
        explanation: _text(record, 'text'),
      ),
      'synonyms' => WordDefinition(
        summary: previous.summary,
        explanation: previous.explanation,
        synonyms: _synonyms(record['items']),
      ),
      'formation' => WordDefinition(
        summary: previous.summary,
        explanation: previous.explanation,
        synonyms: previous.synonyms,
        formation: _text(record, 'text', allowEmpty: true),
      ),
      _ => throw StateError('Unknown word definition section'),
    };
    _nextSection++;
    return _definition;
  }

  /// 只有四条记录齐全时返回最终结果；传输是否成功由调用方确认。
  WordDefinition finish() {
    if (!_definition.isComplete) {
      throw const FormatException('Incomplete word definition');
    }
    return _definition;
  }

  static WordDefinition parse(String content) {
    final parser = WordDefinitionParser();
    for (final line in const LineSplitter().convert(content)) {
      if (line.trim().isEmpty) continue;
      parser.addLine(line);
    }
    return parser.finish();
  }

  static String _text(
    Map<String, dynamic> record,
    String key, {
    bool allowEmpty = false,
  }) {
    final value = record[key];
    if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
      throw FormatException('Invalid word definition field: $key');
    }
    return value.trim();
  }

  static List<WordSynonym> _synonyms(Object? value) {
    if (value is! List) {
      throw const FormatException('Invalid word definition synonyms');
    }
    return List<WordSynonym>.unmodifiable(
      value.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid word definition synonym');
        }
        return WordSynonym(
          word: _text(item, 'word'),
          meaning: _text(item, 'meaning'),
          distinction: _text(item, 'distinction'),
        );
      }),
    );
  }
}
