import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/learning/data/stores/sentence_learning_cache_store.dart';
import 'package:synlen/src/features/learning/data/stores/word_learning_cache_store.dart';

/// 上一版单词键仍带 v2，用于验证本次格式升级不会误读 Markdown。
int _previousWordId(String word, String context) =>
    _fastHash('v2|$word|$context');

int _fastHash(String string) {
  var hash = 0xcbf29ce484222325;
  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }
  return hash;
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('单词解释升级到 v3，上一版 v2 Markdown 缓存不命中', () async {
    final store = WordLearningCacheStore(db);
    await db
        .into(db.wordExplanations)
        .insert(
          WordExplanationsCompanion.insert(
            id: Value(_previousWordId('run', 'I run')),
            word: 'run',
            explanation: '旧格式内容',
            lastUpdated: DateTime.now(),
            context: const Value('I run'),
          ),
        );

    expect(await store.getExplanation('run', 'I run'), isNull);

    await store.saveExplanation(
      word: 'run',
      context: 'I run',
      explanation: '新格式内容',
    );
    final cached = await store.getExplanation('run', 'I run');
    expect(cached!.explanation, '新格式内容');
    expect(cached.id, wordExplanationId('run', 'I run'));
    expect(cached.id, _fastHash('v3|run|I run'));
  });

  test('单词格式升级保留已有 v2 句子缓存及原词音频键', () async {
    const sentence = 'She said hello.';
    await db
        .into(db.sentenceAnalyses)
        .insert(
          SentenceAnalysesCompanion.insert(
            sentence: 'v2|$sentence',
            analysis: '已有句子分析',
            lastUpdated: DateTime.now(),
          ),
        );
    final cached = await SentenceLearningCacheStore(db).getSentence(sentence);
    expect(cached!.analysis, '已有句子分析');
    expect(cached.sentence, 'v2|$sentence');
    expect(wordPronunciationId('sorted'), _fastHash('sorted'));
    expect(sentencePronunciationId(sentence), _fastHash(sentence));
  });

  test('句子分析缓存键带 prompt 版本，旧格式缓存不命中', () async {
    final store = SentenceLearningCacheStore(db);
    await db
        .into(db.sentenceAnalyses)
        .insert(
          SentenceAnalysesCompanion.insert(
            sentence: 'She said hello.',
            analysis: '旧格式内容',
            lastUpdated: DateTime.now(),
          ),
        );

    expect(await store.getSentence('She said hello.'), isNull);

    await store.saveAnalysis(sentence: 'She said hello.', analysis: '新格式内容');
    final cached = await store.getSentence('She said hello.');
    expect(cached!.analysis, '新格式内容');
  });
}
