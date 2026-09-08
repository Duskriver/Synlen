import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/data/services/epub_backend.dart';
import 'package:synlen/src/features/reader/data/services/epub_stream_service.dart';

/// 记录调用序列的 Rust 后端 fake。
class _FakeBackend implements EpubBackend {
  final List<String> calls = [];
  final Map<String, Uint8List> files = {};

  @override
  Future<void> load(String epubPath) async => calls.add('load:$epubPath');

  @override
  Future<Uint8List?> readFile({
    required String epubPath,
    required String filePath,
  }) async {
    calls.add('read:$epubPath/$filePath');
    return files[filePath];
  }

  @override
  Future<void> close(String epubPath) async => calls.add('close:$epubPath');
}

void main() {
  late _FakeBackend backend;
  late EpubStreamService service;

  setUp(() {
    backend = _FakeBackend();
    service = EpubStreamService(backend: backend);
  });

  tearDown(() => service.dispose());

  test('切换书籍时关闭上一本的缓存条目', () async {
    await service.openBook('a.epub');
    await service.openBook('b.epub');

    expect(backend.calls, ['load:a.epub', 'close:a.epub', 'load:b.epub']);
  });

  test('重复打开同一本书不重复加载', () async {
    await service.openBook('a.epub');
    await service.openBook('a.epub');

    expect(backend.calls, ['load:a.epub']);
  });

  test('并发打开同一本书只加载一次', () async {
    await Future.wait([service.openBook('a.epub'), service.openBook('a.epub')]);

    expect(backend.calls, ['load:a.epub']);
  });

  test('读取条目会先确保目标书籍已加载', () async {
    backend.files['ch1.xhtml'] = Uint8List.fromList([1, 2]);

    final result = await service.readFileFromEpub(
      targetFilePath: 'ch1.xhtml',
      epubPath: 'a.epub',
    );

    expect(result.isRight(), isTrue);
    expect(backend.calls, ['load:a.epub', 'read:a.epub/ch1.xhtml']);
  });

  test('条目不存在返回 left', () async {
    final result = await service.readFileFromEpub(
      targetFilePath: 'missing.xhtml',
      epubPath: 'a.epub',
    );

    expect(result.isLeft(), isTrue);
  });

  test('dispose 关闭当前书籍', () async {
    await service.openBook('a.epub');

    service.dispose();

    expect(backend.calls, ['load:a.epub', 'close:a.epub']);
  });
}
