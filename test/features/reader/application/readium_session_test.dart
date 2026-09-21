import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/application/book_queries.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/domain/book_manifest.dart';
import 'package:synlen/src/features/library/domain/book_progress.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';
import 'package:synlen/src/features/reader/application/readium_gateway.dart';
import 'package:synlen/src/features/reader/application/readium_layout.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

Locator position(String href, double ratio) => Locator(
  href: href,
  type: 'application/xhtml+xml',
  locations: Locations(
    progression: ratio,
    fragments: ['p-${(ratio * 100).round()}'],
  ),
  text: const LocatorText(highlight: 'The visible paragraph.'),
);
ReadiumLayout layout(double zoom) => ReadiumLayout(
  EpubTheme(
    zoom: zoom,
    shouldOverrideTextColor: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    padding: EdgeInsets.zero,
  ),
);

class Queries implements BookQueries {
  final saved = <BookProgress>[];
  bool failSave = false;
  @override
  Future<ReaderBookView?> findBook(String fileHash) async => null;
  @override
  Future<ReaderManifestView?> findManifest(String fileHash) async => null;
  @override
  Future<void> saveProgress({
    required int bookId,
    required BookProgress progress,
  }) async {
    if (failSave) throw StateError('disk');
    saved.add(progress);
  }
}

class Gateway implements ReadiumGateway {
  Gateway({int chapters = 2})
    : publication = Publication.fromJson({
        'metadata': {'identifier': 'test-book', 'title': 'Book'},
        'links': <Object>[],
        'readingOrder': [
          for (var index = 1; index <= chapters; index++)
            {'href': 'chapter$index.xhtml', 'type': 'application/xhtml+xml'},
        ],
      });

  final calls = <String>[];
  final preferences = <EPUBPreferences>[];
  Completer<void>? opening;
  final Publication? publication;
  @override
  Future<Publication> open(String path, EPUBPreferences prefs) async {
    calls.add('open');
    preferences.add(prefs);
    await opening?.future;
    return publication!;
  }

  @override
  Future<void> close() async => calls.add('close');
  @override
  Future<void> go(Locator locator, {required bool animated}) async =>
      calls.add('go:${locator.href}');
  @override
  Future<void> turnPage(bool forward, {required bool animated}) async =>
      calls.add('turn:$forward:$animated');
  @override
  Future<String> resource(String href) async => 'file:///tmp/image.png';
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late Queries queries;
  late Gateway gateway;
  late ReadiumSession session;
  void create({
    BookProgress? saved,
    int chapters = 2,
    Duration timeout = const Duration(seconds: 1),
    List<SpineItem> spine = const [],
    BookFormat format = BookFormat.epub,
  }) {
    queries = Queries();
    gateway = Gateway(chapters: chapters);
    session = ReadiumSession(
      fileHash: 'hash',
      queries: queries,
      gateway: gateway,
      layoutDebounce: Duration.zero,
      readyTimeout: timeout,
      prepare: (_) async => (
        path: '/book.epub',
        book: (
          id: 1,
          title: 'Book',
          author: '',
          coverPath: null,
          filePath: 'book.epub',
          totalChapters: chapters,
          direction: 0,
          format: format,
          progress: saved,
        ),
        manifest: (spine: spine, toc: <TocItem>[]),
      ),
    );
  }

  Future<void> start(Locator location) async {
    final opening = session.open(layout(1));
    await tick();
    session.reportLocator(session.sessionId, location);
    session.reportReady(session.sessionId);
    await opening;
  }

  tearDown(() async {
    await session.close();
    session.dispose();
  });

  for (final format in BookFormat.values) {
    test('$format 旧坐标按原清单匹配章节，就绪后才替换为原生 Locator', () async {
      create(
        saved: BookProgress.fromLegacy(
          chapterIndex: 0,
          progression: .6,
          fraction: .8,
        ),
        format: format,
        // 原清单与新阅读顺序不一致，不能直接沿用数组下标。
        spine: [
          SpineItem(href: 'chapter2.xhtml'),
          SpineItem(href: 'chapter1.xhtml'),
        ],
      );
      final opening = session.open(layout(1));
      await tick();
      expect(session.initialLocator!.href, 'chapter2.xhtml');
      expect(session.initialLocator!.locations!.progression, .6);
      expect(session.initialLocator!.text, isNull);
      session.reportReady(session.sessionId);
      session.reportLocator(session.sessionId, position('chapter1.xhtml', 0));
      await session.flush();
      expect(queries.saved, isEmpty);
      final located = position('chapter2.xhtml', .59);
      session.reportLocator(session.sessionId, located);
      await opening;
      await session.flush();
      expect(queries.saved.single.legacy, isNull);
      expect(queries.saved.single.locator, located.toJson());
    });
  }

  test('旧章节缺失时保留旧坐标，不从书首覆盖进度', () async {
    create(
      saved: BookProgress.fromLegacy(
        chapterIndex: 9,
        progression: .4,
        fraction: .8,
      ),
    );
    await session.open(layout(1));
    expect(session.failure, ReaderFailure.load);
    expect(session.publication, isNull);
    await session.flush();
    expect(queries.saved, isEmpty);
  });

  test('首次内容回执前不保存默认位置，首个完整 Locator 带文本原样入库', () async {
    create();
    final opening = session.open(layout(1));
    await tick();
    await session.flush();
    expect(queries.saved, isEmpty);
    final locator = position('chapter1.xhtml', .4);
    session.reportReady(session.sessionId);
    expect(session.ready, isFalse);
    session.reportLocator(session.sessionId, locator);
    await opening;
    await session.flush();
    expect(queries.saved.single.locator, locator.toJson());
    expect(queries.saved.single.fraction, .2);
  });

  test('单章末尾按章内比例显示进度，不采信原生停在零的全书比例', () async {
    create(chapters: 1);
    final location = Locator(
      href: 'chapter1.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(progression: .995, totalProgression: 0),
    );
    await start(location);
    expect(session.fraction, .995);
    await session.flush();
    expect(queries.saved.single.fraction, .995);
    expect(queries.saved.single.locator, location.toJson());
  });

  test('多章内继续翻页会增加等权章节百分比，完整 Locator 保持原值', () async {
    create(chapters: 3);
    final first = Locator(
      href: 'chapter2.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(progression: .25, totalProgression: 1 / 3),
    );
    await start(first);
    expect(session.fraction, closeTo(1.25 / 3, 1e-9));
    await session.flush();
    final next = first.copyWith(
      locations: first.locations!.copyWith(progression: .75),
    );
    session.reportLocator(session.sessionId, next);
    expect(session.fraction, closeTo(1.75 / 3, 1e-9));
    await session.flush();
    expect(
      queries.saved.last.fraction,
      greaterThan(queries.saved.first.fraction),
    );
    expect(queries.saved.map((saved) => saved.locator), [
      first.toJson(),
      next.toJson(),
    ]);
  });

  test('改字号等待旧视口销毁，新视口收到同章位置后才恢复保存', () async {
    create();
    final old = position('chapter2.xhtml', .6);
    await start(old);
    final previousId = session.sessionId;
    session.viewMounted(previousId);
    session.requestLayout(layout(1.5));
    await tick();
    await tick();
    expect(session.ready, isFalse);
    expect(session.publication, isNull);
    expect(gateway.calls, ['open']);
    session.reportLocator(previousId, position('chapter1.xhtml', 0));
    await session.flush();
    expect(queries.saved.last.locator, old.toJson());
    session.viewDisposed(previousId);
    await tick();
    expect(gateway.calls, ['open', 'close', 'open']);
    expect(session.initialLocator, old);
    final newId = session.sessionId;
    session.reportLocator(previousId, position('chapter1.xhtml', 0));
    session.reportLocator(newId, position('chapter1.xhtml', 0));
    session.reportReady(newId);
    expect(session.ready, isFalse);
    session.reportLocator(newId, old);
    await tick();
    expect(session.ready, isTrue);
    expect(gateway.preferences.last.fontSize, 1.5);
    await session.flush();
    expect(queries.saved.last.locator, old.toJson());
  });

  test('连续设置在重建期间合并为最新值，保持最初阅读位置', () async {
    create();
    final old = position('chapter2.xhtml', .6);
    await start(old);
    session.requestLayout(layout(1.2));
    await tick();
    await tick();
    session.requestLayout(layout(1.3));
    session.requestLayout(layout(1.8));
    session.reportLocator(session.sessionId, old);
    session.reportReady(session.sessionId);
    await tick();
    await tick();
    session.reportLocator(session.sessionId, old);
    session.reportReady(session.sessionId);
    await tick();
    expect(gateway.preferences.map((p) => p.fontSize), [1.0, 1.2, 1.8]);
    expect(session.initialLocator, old);
  });

  test('打开尚未完成就关闭，完成的原生书必须关闭且无默认进度', () async {
    create();
    gateway.opening = Completer<void>();
    final opening = session.open(layout(1));
    await tick();
    final closing = session.close();
    gateway.opening!.complete();
    await opening;
    expect(await closing, isTrue);
    expect(gateway.calls, ['open', 'close']);
    expect(queries.saved, isEmpty);
  });

  test('加载超时转可重试错误，重试重新挂载并可保存', () async {
    create(timeout: const Duration(milliseconds: 20));
    await session.open(layout(1));
    expect(session.failure, ReaderFailure.load);
    final retry = session.open(layout(1));
    await tick();
    session.reportLocator(session.sessionId, position('chapter1.xhtml', 0));
    session.reportReady(session.sessionId);
    await retry;
    expect(session.failure, isNull);
    expect(session.ready, isTrue);
    expect(gateway.calls, ['open', 'close', 'open']);
  });

  test('保存失败阻止正常退出且允许重试，关闭幂等且不接收迟到位置', () async {
    create();
    final old = position('chapter2.xhtml', .4);
    await start(old);
    queries.failSave = true;
    expect(await session.flush(), isFalse);
    expect(session.failure, ReaderFailure.progress);
    queries.failSave = false;
    expect(await session.flush(), isTrue);
    final id = session.sessionId;
    await session.close();
    await session.close();
    session.reportLocator(id, position('chapter1.xhtml', 0));
    expect(queries.saved.single.locator, old.toJson());
    expect(gateway.calls.where((call) => call == 'close'), hasLength(1));
  });

  test('关闭时保存失败可重试，成功关闭后不重复释放原生书籍', () async {
    create();
    await start(position('chapter2.xhtml', .4));
    queries.failSave = true;
    expect(await session.close(), isFalse);
    queries.failSave = false;
    expect(await session.close(), isTrue);
    expect(queries.saved, hasLength(1));
    expect(gateway.calls.where((call) => call == 'close'), hasLength(1));
  });

  test('非当前书章节事件丢弃，目录保留fragment且动画参数送达', () async {
    create();
    final old = position('chapter1.xhtml', .4);
    await start(old);
    session.reportLocator(session.sessionId, position('other.xhtml', 0));
    expect(session.locator, old);
    await session.turnPage(true, animated: false);
    await session.goTo('chapter2.xhtml#target');
    expect(gateway.calls, ['open', 'turn:true:false', 'go:chapter2.xhtml']);
  });
}
