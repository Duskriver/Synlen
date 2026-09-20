import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/web/api/reader_web_event.dart';

void main() {
  test('已知消息被解码成各自的事件类型', () {
    final examples = <String, (List<dynamic>, Type)>{
      'onPageCountReady': ([3], ReaderPageCount),
      'onPageChanged': ([1], ReaderPageChanged),
      'onScrollAnchors': (
        [
          ['a', 'b'],
        ],
        ReaderAnchors,
      ),
      'onTap': ([1, 2.5], ReaderTap),
      'onLinkTap': (['book://localhost/book/hash/ch1#top', 1, 2], ReaderLink),
      'onWordTap': (['word', 'a word.', 11, 22.5, 33, 44, 7], ReaderWord),
      'onSentenceSelected': (['A sentence.'], ReaderSentence),
      'onViewportResize': ([], ReaderResize),
      'onEventFinished': ([7], ReaderEventFinished),
      'onImageLongPress': (['image.jpg', 1, 2, 30, 40], ReaderImage),
      'onFootnoteTap': (
        ['<p>note</p>', 1, 2, 30, 40, 'book://localhost/'],
        ReaderFootnote,
      ),
    };
    expect(examples.keys, unorderedEquals(ReaderWebEvent.handlers));
    for (final entry in examples.entries) {
      expect(
        ReaderWebEvent.decode(entry.key, entry.value.$1).runtimeType,
        entry.value.$2,
      );
    }
    final tap = ReaderWebEvent.decode('onTap', [1, 2.5]) as ReaderTap;
    expect((tap.x, tap.y), (1.0, 2.5));
    final word =
        ReaderWebEvent.decode('onWordTap', [
              'word',
              'a word.',
              11,
              22.5,
              33,
              44,
              7,
            ])
            as ReaderWord;
    expect(word.rect, (x: 11.0, y: 22.5, width: 33.0, height: 44.0));
    expect(word.requestId, 7);
  });

  test('截断、错型、非有限坐标、负尺寸与未知消息被拒绝', () {
    for (final name in ReaderWebEvent.handlers) {
      expect(ReaderWebEvent.decode(name, [null]), isNull);
    }
    for (final args in <List<dynamic>>[
      [1],
      [1, '2'],
      [double.nan, 2],
      [1, double.infinity],
    ]) {
      expect(ReaderWebEvent.decode('onTap', args), isNull);
    }
    expect(
      ReaderWebEvent.decode('onImageLongPress', ['a', 0, 0, -1, 1]),
      isNull,
    );
    expect(
      ReaderWebEvent.decode('onScrollAnchors', [
        [1],
      ]),
      isNull,
    );
    expect(ReaderWebEvent.decode('onPageCountReady', [-1]), isNull);
    expect(ReaderWebEvent.decode('unknown', []), isNull);
  });

  test('词回执必须携带非空矩形和有效请求编号', () {
    for (final args in <List<dynamic>>[
      ['word', 'a word.'],
      ['word', 'a word.', 1, 2, 3, 4],
      ['word', 'a word.', double.nan, 2, 3, 4, 1],
      ['word', 'a word.', 1, double.infinity, 3, 4, 1],
      ['word', 'a word.', 1, 2, 0, 4, 1],
      ['word', 'a word.', 1, 2, 3, -1, 1],
      ['word', 'a word.', 1, 2, 3, 4, 0],
      ['word', 'a word.', 1, 2, 3, 4, '1'],
    ]) {
      expect(ReaderWebEvent.decode('onWordTap', args), isNull);
    }
  });
}
