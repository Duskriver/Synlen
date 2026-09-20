import 'dart:async';
import '../../word_definition_fixture.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';

import '../repositories/learning_repository_test.dart'
    show InMemoryAudioFileStore, InMemoryWordCacheStore;
import 'deep_seek_service_test.dart' show FakeChatAdapter, body, event;

class ConcurrentChatAdapter implements HttpClientAdapter {
  final requests = <Completer<ResponseBody>>[];
  final cancelled = <bool>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final index = requests.length;
    final response = Completer<ResponseBody>();
    requests.add(response);
    cancelled.add(false);
    cancelFuture?.then((_) => cancelled[index] = true);
    return response.future;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  setUp(() => dio = Dio());
  tearDown(() => dio.close(force: true));

  test('取消词典等待时终止 HTTP，不得发起 TTS 回退', () async {
    final response = Completer<ResponseBody>();
    final adapter = FakeChatAdapter((_) => response.future);
    dio.httpClientAdapter = adapter;
    var ttsKeyReads = 0;
    final cancellation = LearningCancellation();
    final repository = WordRepository(
      FreeDictionaryService(dio: dio),
      DeepSeekService(dio: dio),
      AliyunTTSService(
        dio: dio,
        readApiKey: () {
          ttsKeyReads++;
          return 'test-key';
        },
      ),
      InMemoryWordCacheStore(),
      InMemoryAudioFileStore(),
    );
    final result = expectLater(
      repository
          .getPronunciationStream('word', cancellation: cancellation)
          .toList(),
      throwsA(isA<LearningCancelled>()),
    );
    await adapter.started.future;
    cancellation.cancel();
    await result;
    await adapter.cancelled.future.timeout(const Duration(seconds: 1));
    expect(ttsKeyReads, 0);
    response.complete(body(''));
  });

  test('TTS 在等待响应头时收到查询取消', () async {
    final response = Completer<ResponseBody>();
    final adapter = FakeChatAdapter((_) => response.future);
    dio.httpClientAdapter = adapter;
    final cancellation = LearningCancellation();
    final tts = AliyunTTSService(dio: dio, readApiKey: () => 'test-key');
    final result = expectLater(
      tts.generateAudioStream('Sentence.', cancellation: cancellation).toList(),
      throwsA(isA<LearningCancelled>()),
    );
    await adapter.started.future;
    cancellation.cancel();
    await result;
    await adapter.cancelled.future.timeout(const Duration(seconds: 1));
    response.complete(body(''));
  });

  test('TTS 在没有音频首包时取消并释放正文', () async {
    final listening = Completer<void>();
    final cancelled = Completer<void>();
    final source = StreamController<Uint8List>(
      onListen: listening.complete,
      onCancel: cancelled.complete,
    );
    dio.httpClientAdapter = FakeChatAdapter(
      (_) async => ResponseBody(source.stream, 200),
    );
    final cancellation = LearningCancellation();
    final result = expectLater(
      AliyunTTSService(
        dio: dio,
        readApiKey: () => 'test-key',
      ).generateAudioStream('S.', cancellation: cancellation).toList(),
      throwsA(isA<LearningCancelled>()),
    );
    await listening.future;
    cancellation.cancel();
    await result;
    await cancelled.future.timeout(const Duration(seconds: 1));
    await source.close();
  });

  test('共用 DeepSeek 客户端时只取消所属查询，另一查询仍成功', () async {
    final adapter = ConcurrentChatAdapter();
    dio.httpClientAdapter = adapter;
    final client = DeepSeekService(dio: dio, readApiKey: () => 'test-key');
    final first = LearningCancellation();
    final firstResult = expectLater(
      client.analyzeSentenceStream('First.', cancellation: first).toList(),
      throwsA(isA<LearningCancelled>()),
    );
    final secondResult = client.analyzeSentenceStream('Second.').toList();
    while (adapter.requests.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    first.cancel();
    await firstResult;
    await Future<void>.delayed(Duration.zero);
    expect(adapter.cancelled, [true, false]);
    adapter.requests[0].complete(body(''));
    adapter.requests[1].complete(
      body('${event(content: '第二句')}${event(reason: 'stop')}data: [DONE]\n\n'),
    );
    expect(await secondResult, ['第二句']);
  });

  test('单词解释已有部分正文时取消不得写入缓存', () async {
    final source = StreamController<Uint8List>();
    dio.httpClientAdapter = FakeChatAdapter(
      (_) async => ResponseBody(source.stream, 200),
    );
    final cache = InMemoryWordCacheStore();
    final cancellation = LearningCancellation();
    final repository = WordRepository(
      FreeDictionaryService(dio: dio),
      DeepSeekService(dio: dio, readApiKey: () => 'test-key'),
      AliyunTTSService(dio: dio),
      cache,
      InMemoryAudioFileStore(),
    );
    final firstChunk = Completer<void>();
    final finished = Completer<void>();
    final errors = <Object>[];
    repository
        .getContentStream(
          const WordLearningQuery(word: 'word', context: 'context'),
          cancellation: cancellation,
        )
        .listen(
          (_) => firstChunk.complete(),
          onError: errors.add,
          onDone: finished.complete,
        );
    source.add(
      Uint8List.fromList(utf8.encode(event(content: wordSummaryRecord))),
    );
    await firstChunk.future;
    cancellation.cancel();
    await finished.future.timeout(const Duration(seconds: 1));
    expect(errors, hasLength(1));
    expect(cache.explanations, isEmpty);
    await source.close();
  });

  test('已取消的信号立即取消后注册的操作，注销后不再触发', () {
    final cancellation = LearningCancellation();
    var removedCalls = 0;
    var activeCalls = 0;
    final unregister = cancellation.onCancel(() => removedCalls++);
    cancellation.onCancel(() => activeCalls++);
    unregister();
    cancellation.cancel();
    cancellation.cancel();
    cancellation.onCancel(() => activeCalls++);
    expect(removedCalls, 0);
    expect(activeCalls, 2);
    expect(cancellation.throwIfCancelled, throwsA(isA<LearningCancelled>()));
  });
}
