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
    'anchorRect': {'x': 10, 'y': 20, 'width': 40, 'height': 18.5},
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
    expect(parse(valid)?.anchorRect, (
      x: 10.0,
      y: 20.0,
      width: 40.0,
      height: 18.5,
    ));
  });
  test('单词必须带完整的有限正尺寸矩形', () {
    expect(parse({...valid}..remove('anchorRect')), isNull);
    for (final rect in <Object>[
      [],
      {},
      {'x': 10, 'y': 20, 'width': 40},
      {'x': '10', 'y': 20, 'width': 40, 'height': 18},
      {'x': 10, 'y': 20, 'width': 0, 'height': 18},
      {'x': 10, 'y': 20, 'width': 40, 'height': -1},
      {'x': 1e308, 'y': 20, 'width': 1e308, 'height': 18},
    ]) {
      expect(parse({...valid, 'anchorRect': rect}), isNull);
    }
    expect(
      ReadiumInteraction.parse(
        jsonEncode(valid).replaceFirst('"width":40', '"width":1e309'),
        sessionId: 'current',
        currentHref: 'Text/a b.xhtml',
      ),
      isNull,
    );
  });
  test('部分超出视口的矩形交展示层裁剪，句子和controls不要求矩形', () {
    expect(
      parse({
        ...valid,
        'anchorRect': {'x': -5, 'y': 20, 'width': 40, 'height': 18},
      })?.anchorRect,
      (x: -5.0, y: 20.0, width: 40.0, height: 18.0),
    );
    final noRect = {...valid}..remove('anchorRect');
    expect(parse({...noRect, 'kind': 'sentence'})?.sentence, valid['sentence']);
    expect(parse({...noRect, 'kind': 'controls'})?.kind, 'controls');
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
