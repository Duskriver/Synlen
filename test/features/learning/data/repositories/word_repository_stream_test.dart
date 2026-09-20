import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';

import '../../word_definition_fixture.dart';
import 'learning_repository_test.dart'
    show InMemoryAudioFileStore, InMemoryWordCacheStore, testDio;

class StreamingWordService extends DeepSeekService {
  StreamingWordService(this.source) : super(dio: testDio());

  final Stream<String> source;

  @override
  Stream<String> explainWordStream(
    String word,
    String context, {
    LearningCancellation? cancellation,
  }) => source;
}

void main() {
  const query = WordLearningQuery(
    word: 'sorted',
    context: 'They sorted books.',
  );
  late InMemoryWordCacheStore cache;

  setUp(() => cache = InMemoryWordCacheStore());

  WordRepository repository(Stream<String> source) => WordRepository(
    FreeDictionaryService(dio: testDio()),
    StreamingWordService(source),
    AliyunTTSService(dio: testDio()),
    cache,
    InMemoryAudioFileStore(),
  );

  test('合并分包后立即发布简义，后续未到时不等待也不缓存', () async {
    final source = StreamController<String>();
    final summary = Completer<void>();
    final finished = Completer<void>();
    final records = <String>[];
    repository(source.stream).getContentStream(query).listen((record) {
      records.add(record);
      if (!summary.isCompleted) summary.complete();
    }, onDone: finished.complete);
    source.add(wordSummaryRecord.substring(0, 17));
    source.add(wordSummaryRecord.substring(17));
    await summary.future.timeout(const Duration(seconds: 1));
    expect(records, [wordSummaryRecord]);
    expect(cache.explanations, isEmpty);
    source.add('$wordExplanationRecord$wordSynonymsRecord$wordFormationRecord');
    await source.close();
    await finished.future;
    expect(records, wordDefinitionRecords);
    expect(
      cache.explanations['sorted|They sorted books.']!.explanation,
      wordDefinitionContent,
    );
  });

  test('CRLF 和没有末尾换行的最后记录仍完整落缓存', () async {
    final input = wordDefinitionContent.trimRight().replaceAll('\n', '\r\n');
    final records = await repository(
      Stream.fromIterable(input.split('')),
    ).getContentStream(query).toList();
    expect(records, wordDefinitionRecords);
    expect(cache.explanations.values.single.explanation, wordDefinitionContent);
  });

  final invalidResponses = {
    '缺少后续记录': wordSummaryRecord,
    '损坏后续记录': '$wordSummaryRecord{invalid}\n',
    '重复记录': '$wordSummaryRecord$wordSummaryRecord',
    '错误顺序': '$wordSummaryRecord$wordSynonymsRecord',
    '完成后额外记录': '$wordDefinitionContent$wordFormationRecord',
  };
  for (final entry in invalidResponses.entries) {
    test('${entry.key} 不写入缓存', () async {
      await expectLater(
        repository(Stream.value(entry.value)).getContentStream(query).toList(),
        throwsFormatException,
      );
      expect(cache.explanations, isEmpty);
    });
  }

  test('四条内容齐全但传输随后失败仍不得缓存', () async {
    final source = StreamController<String>();
    final received = <String>[];
    final result = repository(
      source.stream,
    ).getContentStream(query).forEach(received.add);
    final expectation = expectLater(result, throwsStateError);
    source.add(wordDefinitionContent);
    source.addError(StateError('transport failed'));
    await source.close();
    await expectation;
    expect(received, wordDefinitionRecords);
    expect(cache.explanations, isEmpty);
  });

  test('最后记录后查询已取消，不写入完整内容', () async {
    final cancellation = LearningCancellation();
    final result = repository(Stream.value(wordDefinitionContent))
        .getContentStream(query, cancellation: cancellation)
        .forEach((record) {
          if (record == wordFormationRecord) cancellation.cancel();
        });
    await expectLater(result, throwsA(isA<LearningCancelled>()));
    expect(cache.explanations, isEmpty);
  });
}
