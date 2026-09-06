import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;

  FakePathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory root;
  late PathProviderPlatform originalProvider;
  late Directory audioDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-audio-evict-');
    audioDir = Directory('${root.path}/audio');
    await audioDir.create(recursive: true);
    originalProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
  });

  tearDown(() {
    PathProviderPlatform.instance = originalProvider;
    root.deleteSync(recursive: true);
  });

  Future<File> createAudio(String name, int size, DateTime modified) async {
    final file = File('${audioDir.path}/$name');
    await file.writeAsBytes(List.filled(size, 1));
    await file.setLastModified(modified);
    return file;
  }

  const store = LearningAudioFileStore();

  test('未超预算时不清退任何文件', () async {
    await createAudio('word_a.pcm', 100, DateTime(2026, 1, 1));
    await createAudio('sentence_b__voice.pcm', 100, DateTime(2026, 1, 2));

    expect(await store.evictAudioCache(maxBytes: 1000), 0);
    expect(audioDir.listSync(), hasLength(2));
  });

  test('超预算时按修改时间最旧优先清退', () async {
    final oldest = await createAudio('word_old.pcm', 300, DateTime(2026, 1, 1));
    final middle = await createAudio('word_mid.pcm', 300, DateTime(2026, 1, 2));
    final newest = await createAudio(
      'sentence_new__voice.pcm',
      300,
      DateTime(2026, 1, 3),
    );

    // 总量 900，预算 500：清退最旧两个文件后剩余 300，满足预算。
    final deleted = await store.evictAudioCache(maxBytes: 500);
    expect(deleted, 2);
    expect(oldest.existsSync(), isFalse);
    expect(middle.existsSync(), isFalse);
    expect(newest.existsSync(), isTrue);
  });

  test('maxBytes 为 0 时清空全部音频', () async {
    await createAudio('word_a.pcm', 10, DateTime(2026, 1, 1));
    await createAudio('sentence_b__voice.pcm', 10, DateTime(2026, 1, 2));

    expect(await store.evictAudioCache(maxBytes: 0), 2);
    expect(audioDir.listSync(), isEmpty);
  });

  test('音频目录不存在时返回 0', () async {
    await audioDir.delete();
    expect(await store.evictAudioCache(maxBytes: 0), 0);
  });
}
