import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/application/reading_progress_controller.dart';
import 'package:synlen/src/features/library/domain/book_progress.dart';

BookProgress position(int page, {int chapter = 0, int count = 10}) =>
    BookProgress.fromLocator({
      'href': 'chapter-$chapter.xhtml',
      'type': 'application/xhtml+xml',
      'locations': {'progression': page / count},
    }, fraction: page / count);

void main() {
  test('连续翻页只提交最后完整位置', () {
    fakeAsync((clock) {
      final saved = <BookProgress>[];
      final controller = ReadingProgressController(
        save: (progress) async => saved.add(progress),
        onSaveFailed: () => fail('不应保存失败'),
      );
      controller.record(position(1), isReady: true);
      clock.elapse(const Duration(milliseconds: 700));
      controller.record(position(4), isReady: true);
      clock.elapse(const Duration(milliseconds: 700));
      expect(saved, isEmpty);
      clock.elapse(const Duration(milliseconds: 300));
      expect(saved, [position(4)]);
      unawaited(controller.close());
      clock.flushMicrotasks();
    });
  });

  test('定时器尚未触发时关闭，仍完成提交且不再写第二次', () {
    fakeAsync((clock) {
      final saved = <BookProgress>[];
      final controller = ReadingProgressController(
        save: (progress) async => saved.add(progress),
        onSaveFailed: () => fail('不应保存失败'),
      );
      controller.record(position(5), isReady: true);
      bool? closed;
      controller.close().then((result) => closed = result);
      clock.flushMicrotasks();
      expect(closed, isTrue);
      expect(saved, [position(5)]);
      controller.record(position(7), isReady: true);
      clock.elapse(const Duration(seconds: 2));
      expect(saved, [position(5)]);
      expect(clock.pendingTimers, isEmpty);
    });
  });

  test('慢写入期间合并新位置，所有 flush 等到最后一笔完成', () async {
    final calls = <BookProgress>[];
    final writes = <Completer<void>>[];
    final controller = ReadingProgressController(
      save: (progress) {
        calls.add(progress);
        final write = Completer<void>();
        writes.add(write);
        return write.future;
      },
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record(position(1), isReady: true);
    var completed = false;
    final flushing = controller.flush().then((value) => completed = value);
    controller.record(position(3), isReady: true);
    controller.record(position(8, chapter: 1), isReady: true);
    final closing = controller.close();
    controller.record(position(9, chapter: 2), isReady: true);
    expect(calls, [position(1)]);
    writes.first.complete();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [position(1), position(8, chapter: 1)]);
    expect(completed, isFalse);
    writes.last.complete();
    expect(await closing, isTrue);
    await flushing;
    expect(completed, isTrue);
  });

  test('返回已保存位置时仍等待在途新位置写完，再写回目标位置', () async {
    final calls = <BookProgress>[];
    final slowWrite = Completer<void>();
    final controller = ReadingProgressController(
      save: (progress) async {
        calls.add(progress);
        if (progress.locator['locations']['progression'] == 0.2) {
          await slowWrite.future;
        }
      },
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record(position(1), isReady: true);
    await controller.flush();
    controller.record(position(2), isReady: true);
    final flushing = controller.flush();
    controller.record(position(1), isReady: true);
    final closing = controller.close();
    slowWrite.complete();
    await flushing;
    expect(await closing, isTrue);
    expect(calls, [position(1), position(2), position(1)]);
  });

  test('加载中的临时定位不能覆盖最后有效位置', () async {
    final saved = <BookProgress>[];
    final controller = ReadingProgressController(
      save: (progress) async => saved.add(progress),
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record(position(4, chapter: 2), isReady: true);
    controller.record(position(0, chapter: 3), isReady: false);
    expect(await controller.close(), isTrue);
    expect(saved, [position(4, chapter: 2)]);
  });

  test('首次加载未完成就退出，不写默认位置', () async {
    final controller = ReadingProgressController(
      save: (_) async => fail('未确认位置不得入库'),
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record(position(0), isReady: false);
    expect(await controller.close(), isTrue);
  });

  test('保存失败保留位置且通知一次，显式刷新可重试', () async {
    var failWrite = true;
    var failures = 0;
    final calls = <BookProgress>[];
    final controller = ReadingProgressController(
      save: (progress) async {
        calls.add(progress);
        if (failWrite) throw StateError('磁盘不可写');
      },
      onSaveFailed: () => failures++,
    );
    controller.record(position(6), isReady: true);
    expect(await controller.flush(), isFalse);
    expect(await controller.flush(), isFalse);
    expect(failures, 1);
    failWrite = false;
    expect(await controller.flush(), isTrue);
    expect(calls, List.filled(3, position(6)));
    expect(await controller.close(), isTrue);
    expect(calls, hasLength(3));
  });

  test('旧写入失败期间出现新位置，重试只提交最新位置', () async {
    final firstWrite = Completer<void>();
    final calls = <BookProgress>[];
    final controller = ReadingProgressController(
      save: (progress) async {
        calls.add(progress);
        if (calls.length == 1) await firstWrite.future;
      },
      onSaveFailed: () {},
    );
    controller.record(position(2), isReady: true);
    final flushing = controller.flush();
    controller.record(position(7), isReady: true);
    firstWrite.completeError(StateError('第一次写入失败'));
    expect(await flushing, isFalse);
    expect(await controller.close(), isTrue);
    expect(calls, [position(2), position(7)]);
  });

  test('后台自动提交失败不会逃逸异常，关闭时重新提交', () {
    fakeAsync((clock) {
      var failWrite = true;
      var failures = 0;
      final calls = <BookProgress>[];
      final controller = ReadingProgressController(
        save: (progress) async {
          calls.add(progress);
          if (failWrite) throw StateError('磁盘不可写');
        },
        onSaveFailed: () => failures++,
      );
      controller.record(position(2), isReady: true);
      clock.elapse(const Duration(seconds: 1));
      expect(failures, 1);
      failWrite = false;
      unawaited(controller.close());
      clock.flushMicrotasks();
      expect(calls, [position(2), position(2)]);
      expect(clock.pendingTimers, isEmpty);
    });
  });

  test('重复刷新同一位置不重复写入', () async {
    final saved = <BookProgress>[];
    final controller = ReadingProgressController(
      save: (progress) async => saved.add(progress),
      onSaveFailed: () => fail('不应保存失败'),
    );
    controller.record(position(4), isReady: true);
    await controller.flush();
    controller.record(position(4), isReady: true);
    await controller.flush();
    await controller.close();
    await controller.close();
    expect(saved, [position(4)]);
  });
}
