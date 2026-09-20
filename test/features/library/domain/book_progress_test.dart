import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/domain/book_progress.dart';

void main() {
  Map<String, dynamic> locator() => {
    'href': 'OEBPS/chapter.xhtml',
    'type': 'application/xhtml+xml',
    'title': '第三章',
    'locations': {
      'progression': 0.2,
      'totalProgression': 0.6,
      'cssSelector': '#p-12',
    },
    'text': {'highlight': '原文', 'before': '前', 'after': '后'},
    'extension': {
      'nested': [1, true, null],
    },
  };

  test('完整 Locator 往返保留文本和未知字段，快照不受外部修改影响', () {
    final input = locator();
    final progress = BookProgress.fromLocator(input);
    input['locations']['progression'] = 0.9;
    final copy = progress.locator;
    copy['text']['highlight'] = '改写';
    expect(progress.locator, locator());
    expect(progress.fraction, 0.6);
    expect(progress.chapterTitle, '第三章');
    expect(BookProgress.fromJson(progress.toJson()), progress);
  });

  test('书架投影使用调用方提供的全书分数，不把章内比例冒充全书进度', () {
    final input = locator()..['locations'] = {'progression': 0.8};
    expect(BookProgress.fromLocator(input).fraction, 0);
    final progress = BookProgress.fromLocator(input, fraction: 0.4);
    expect(BookProgress.fromJson(progress.toJson()).fraction, 0.4);
    expect(progress.locator['locations'], {'progression': 0.8});
  });

  test('拒绝不可恢复的定位和非有限百分比，显示分数限制到 0–1', () {
    expect(() => BookProgress.fromLocator({}), throwsFormatException);
    expect(
      () => BookProgress.fromLocator(locator(), fraction: double.nan),
      throwsFormatException,
    );
    expect(BookProgress.fromLocator(locator(), fraction: 2).fraction, 1);
    expect(BookProgress.fromLocator(locator(), fraction: -1).fraction, 0);
  });
}
