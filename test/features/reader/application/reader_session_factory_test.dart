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
import 'package:synlen/src/features/reader/application/readium_publication_source.dart';
import 'package:synlen/src/features/reader/application/readium_session.dart';
import 'package:synlen/src/features/reader/application/reader_session_factory.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

class _Queries implements BookQueries {
  final saved = <int, BookProgress>{};
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
    if (failSave) throw StateError('存储不可用');
    saved[bookId] = progress;
  }
}

class _Gateway implements ReadiumGateway {
  final calls = <String>[];
  final opening = <String, Completer<void>>{};
  Completer<void>? closing;
  bool failClose = false;
  String? owner;
  @override
  Future<Publication> open(String path, EPUBPreferences preferences) async {
    calls.add('open:$path');
    expect(owner, isNull, reason: '旧出版物必须先完成释放');
    owner = path;
    await opening[path]?.future;
    return Publication.fromJson({
      'metadata': {'identifier': path, 'title': path},
      'links': <Object>[],
      'readingOrder': [
        {'href': 'chapter.xhtml', 'type': 'application/xhtml+xml'},
      ],
    })!;
  }

  @override
  Future<void> close() async {
    calls.add('close:$owner');
    await closing?.future;
    if (failClose) throw StateError('原生释放失败');
    owner = null;
  }

  @override
  Future<void> go(Locator locator, {required bool animated}) async {}
  @override
  Future<void> turnPage(bool forward, {required bool animated}) async {}
  @override
  Future<String> resource(String href) async => href;
}

final _layout = ReadiumLayout(
  EpubTheme(
    zoom: 1,
    shouldOverrideTextColor: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
    padding: EdgeInsets.zero,
  ),
);
Future<void> _tick() => Future<void>.delayed(Duration.zero);
void _ready(ReadiumSession session) {
  session.reportLocator(
    session.sessionId,
    Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(progression: .4),
      text: const LocatorText(highlight: 'A complete visible paragraph.'),
    ),
  );
  session.reportReady(session.sessionId);
}

void main() {
  late _Queries queries;
  late _Gateway gateway;
  late ReaderSessionFactory factory;
  final sessions = <ReadiumSession>[];
  setUp(() {
    queries = _Queries();
    gateway = _Gateway();
    sessions.clear();
    Future<PreparedReadiumPublication> prepare(String hash) async => (
      path: '/$hash.epub',
      book: (
        id: hash.codeUnitAt(0),
        title: hash,
        author: '',
        coverPath: null,
        filePath: '$hash.epub',
        totalChapters: 1,
        direction: 0,
        format: BookFormat.epub,
        progress: null,
      ),
      manifest: (spine: <SpineItem>[], toc: <TocItem>[]),
    );
    factory = ReaderSessionFactory(
      prepare: prepare,
      queries: queries,
      gateway: gateway,
    );
  });
  ReadiumSession create(String hash) {
    final session = factory.create(hash);
    sessions.add(session);
    return session;
  }

  Future<void> start(ReadiumSession session) async {
    final work = session.open(_layout);
    await _tick();
    _ready(session);
    await work;
  }

  tearDown(() async {
    gateway.failClose = false;
    queries.failSave = false;
    if (gateway.closing?.isCompleted == false) gateway.closing!.complete();
    for (final pending in gateway.opening.values) {
      if (!pending.isCompleted) pending.complete();
    }
    for (final session in sessions.reversed) {
      await session.close();
      session.dispose();
    }
    factory.dispose();
    await _tick();
  });

  test('原生关闭失败不能被未打开的中间会话绕过，恢复后可重试', () async {
    final a = create('a');
    await start(a);
    gateway.failClose = true;
    final b = create('b');
    await b.open(_layout);
    expect(b.failure, ReaderFailure.load);
    expect(await b.close(), isTrue);
    final c = create('c');
    await c.open(_layout);
    expect(c.failure, ReaderFailure.load);
    expect(gateway.calls, ['open:/a.epub', 'close:/a.epub', 'close:/a.epub']);
    expect(gateway.owner, '/a.epub');
    gateway.failClose = false;
    await start(c);
    expect(c.ready, isTrue);
    expect(gateway.owner, '/c.epub');
    expect(gateway.calls.last, 'open:/c.epub');
  });

  test('前任进度保存失败即使原生已关闭也不丢失待保存位置', () async {
    await start(create('a'));
    queries.failSave = true;
    final b = create('b');
    await b.open(_layout);
    expect(b.failure, ReaderFailure.load);
    expect(gateway.owner, isNull);
    expect(gateway.calls, ['open:/a.epub', 'close:/a.epub']);
    queries.failSave = false;
    await start(b);
    expect(queries.saved['a'.codeUnitAt(0)]!.locator!['text'], {
      'highlight': 'A complete visible paragraph.',
    });
    expect(gateway.calls, ['open:/a.epub', 'close:/a.epub', 'open:/b.epub']);
  });

  test('并发打开在途 B 与 C，C 等 B 打开返回并释放后才能占用原生书', () async {
    await start(create('a'));
    final b = create('b');
    gateway.opening['/b.epub'] = Completer<void>();
    final openingB = b.open(_layout);
    await _tick();
    expect(gateway.owner, '/b.epub');
    final c = create('c');
    final openingC = c.open(_layout);
    await _tick();
    expect(gateway.calls, ['open:/a.epub', 'close:/a.epub', 'open:/b.epub']);
    gateway.opening['/b.epub']!.complete();
    await openingB;
    await _tick();
    _ready(c);
    await openingC;
    expect(gateway.calls, [
      'open:/a.epub',
      'close:/a.epub',
      'open:/b.epub',
      'close:/b.epub',
      'open:/c.epub',
    ]);
    expect(c.ready, isTrue);
    expect(queries.saved.containsKey('b'.codeUnitAt(0)), isFalse);
  });

  test('factory 销毁阻止排队交接后的书打开，并释放当前出版物', () async {
    await start(create('a'));
    gateway.closing = Completer<void>();
    final b = create('b');
    final openingB = b.open(_layout);
    await _tick();
    final c = create('c');
    final openingC = c.open(_layout);
    factory.dispose();
    gateway.closing!.complete();
    await Future.wait([openingB, openingC]);
    await _tick();
    expect(gateway.owner, isNull);
    expect(gateway.calls.where((call) => call.startsWith('open:')), [
      'open:/a.epub',
    ]);
    expect(b.ready, isFalse);
    expect(c.ready, isFalse);
  });

  test('factory 销毁后创建的会话明确失败且不打开原生资源', () async {
    factory.dispose();
    final session = create('a');
    await session.open(_layout);
    expect(session.failure, ReaderFailure.load);
    expect(gateway.calls, isEmpty);
  });
}
