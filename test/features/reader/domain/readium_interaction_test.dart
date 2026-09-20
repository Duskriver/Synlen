import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/domain/readium_interaction.dart';

void main() {
  final valid = <String, Object>{
    'version': 1,
    'sessionId': 'current',
    'resourceHref': 'Text/a%20b.xhtml',
    'kind': 'word',
    'word': 'well-being',
    'sentence': 'We value well-being.',
  };
  ReadiumInteraction? parse(Map<String, Object> values) =>
      ReadiumInteraction.parse(
        jsonEncode(values),
        sessionId: 'current',
        currentHref: 'Text/a b.xhtml',
      );
  test('可信会话和章节一致时返回完整词句，路径允许等价百分号编码', () {
    expect(parse(valid)?.word, 'well-being');
    expect(parse(valid)?.sentence, 'We value well-being.');
  });
  test('旧会话、预载章节、未知版本和空文本不进入学习', () {
    for (final change in <Map<String, Object>>[
      {'sessionId': 'old'},
      {'resourceHref': 'Text/next.xhtml'},
      {'version': 2},
      {'sentence': ''},
      {'word': ''},
      {'kind': 'other'},
      {'word': 'x' * 513},
    ]) {
      expect(parse({...valid, ...change}), isNull);
    }
  });
  test('空白点击只产生controls，损坏和过长消息丢弃', () {
    expect(parse({...valid, 'kind': 'controls'})?.kind, 'controls');
    expect(
      ReadiumInteraction.parse('{', sessionId: 'current', currentHref: 'a'),
      isNull,
    );
    expect(
      ReadiumInteraction.parse(
        'x' * 65537,
        sessionId: 'current',
        currentHref: 'a',
      ),
      isNull,
    );
  });
}
