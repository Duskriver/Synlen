import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service.dart';
import 'package:synlen/src/features/learning/data/stores/learning_audio_file_store.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final String documentsPath;

  FakePathProviderPlatform(this.documentsPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  late Directory root;
  late AppDatabase db;
  late Directory audioDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('synlen-learning-clean-');
    audioDir = Directory('${root.path}/audio');
    await audioDir.create(recursive: true);
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      root.deleteSync(recursive: true);
    });
  });

  Future<void> seedCaches() async {
    await db
        .into(db.wordExplanations)
        .insert(
          WordExplanationsCompanion.insert(
            id: const Value(1),
            word: 'run',
            explanation: '解释',
            lastUpdated: DateTime.now(),
          ),
        );
    await db
        .into(db.wordPronunciations)
        .insert(
          WordPronunciationsCompanion.insert(
            id: const Value(1),
            word: 'run',
            audioUrl: const Value('audio/word_run.mp3'),
            lastUpdated: DateTime.now(),
          ),
        );
    await db
        .into(db.sentenceAnalyses)
        .insert(
          SentenceAnalysesCompanion.insert(
            sentence: 'v2|hello',
            analysis: '分析',
            lastUpdated: DateTime.now(),
          ),
        );
    await db
        .into(db.sentencePronunciations)
        .insert(
          SentencePronunciationsCompanion.insert(
            id: const Value(1),
            sentence: 'hello',
            audioUrl: const Value('audio/sentence_1a.pcm'),
            lastUpdated: DateTime.now(),
          ),
        );
    await File('${audioDir.path}/word_run.mp3').writeAsBytes([1]);
    await File('${audioDir.path}/sentence_1a.pcm').writeAsBytes([2, 3]);
  }

  test('清理后文本表与音频全部移除，并返回音频文件数', () async {
    await seedCaches();
    final service = LearningCacheCleanupService(
      db: db,
      audioFileStore: const LearningAudioFileStore(),
    );

    expect(await service.cleanAll(), 2);

    expect(await db.select(db.wordExplanations).get(), isEmpty);
    expect(await db.select(db.wordPronunciations).get(), isEmpty);
    expect(await db.select(db.sentenceAnalyses).get(), isEmpty);
    expect(await db.select(db.sentencePronunciations).get(), isEmpty);
    expect(audioDir.listSync(), isEmpty);
  });

  test('重复清理为幂等空操作', () async {
    await seedCaches();
    final service = LearningCacheCleanupService(
      db: db,
      audioFileStore: const LearningAudioFileStore(),
    );
    await service.cleanAll();
    expect(await service.cleanAll(), 0);
  });
}
