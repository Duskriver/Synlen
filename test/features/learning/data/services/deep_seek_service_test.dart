import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/domain/learning_exception.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/repositories/sentence_repository.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';

import '../repositories/learning_repository_test.dart'
    show
        InMemoryWordCacheStore,
        InMemoryAudioFileStore,
        InMemorySentenceAnalysisStore,
        InMemorySentencePronunciationStore;

class FakeChatAdapter implements HttpClientAdapter {
  FakeChatAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final started = Completer<RequestOptions>();
  final cancelled = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    started.complete(options);
    cancelFuture?.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

String event({String? content, String? reason}) =>
    'data: ${jsonEncode({
      'choices': [
        {
          'delta': {'content': content},
          'finish_reason': reason,
        },
      ],
    })}\r\n\r\n';

ResponseBody body(String text) => ResponseBody(
  // 每个字节单独到达，覆盖中文 UTF-8 和 SSE 行边界分包。
  Stream.fromIterable(
    utf8.encode(text).map((byte) => Uint8List.fromList([byte])),
  ),
  200,
);

Matcher learningError(LearningErrorCode code) =>
    isA<LearningException>().having((error) => error.code, 'code', code);

void main() {
  late Dio dio;

  setUp(() => dio = Dio());
  tearDown(() => dio.close(force: true));

  DeepSeekService service({
    FutureOr<String> Function()? readApiKey,
    Duration idleTimeout = const Duration(seconds: 30),
    Duration requestTimeout = const Duration(minutes: 2),
  }) => DeepSeekService(
    dio: dio,
    readApiKey: readApiKey ?? () => 'test-key',
    idleTimeout: idleTimeout,
    requestTimeout: requestTimeout,
  );

  test('两种学习请求使用明确模型参数，重组分包并识别正常完成', () async {
    for (final wordRequest in [true, false]) {
      final adapter = FakeChatAdapter(
        (_) async => body(
          ': keep-alive\r\n\r\n'
          '${event(content: '中文')}${event(content: '解释')}'
          '${event(reason: 'stop')}data:[DONE]\r\n\r\n',
        ),
      );
      dio.httpClientAdapter = adapter;
      final client = service();
      final stream = wordRequest
          ? client.explainWordStream('word', 'A word.')
          : client.analyzeSentenceStream('A sentence.');
      expect(await stream.toList(), ['中文', '解释']);
      final request = await adapter.started.future;
      expect(request.headers['Authorization'], 'Bearer test-key');
      expect(request.data['model'], 'deepseek-v4-flash');
      expect(request.data['thinking'], {'type': 'disabled'});
      expect(request.data['max_tokens'], 4096);
      expect(request.sendTimeout, isNotNull);
      expect(request.receiveTimeout, const Duration(seconds: 30));
    }
  });

  test('prompt 固定输出契约：单词四节、句子两节且不回显原句', () async {
    Future<String> capturePrompt(Future<void> Function() send) async {
      final adapter = FakeChatAdapter(
        (_) async => body(
          '${event(content: 'x')}${event(reason: 'stop')}data: [DONE]\n\n',
        ),
      );
      dio.httpClientAdapter = adapter;
      await send();
      final request = await adapter.started.future;
      final messages = request.data['messages'] as List<dynamic>;
      return (messages.last as Map<String, dynamic>)['content'] as String;
    }

    final wordPrompt = await capturePrompt(
      () => service().explainWordStream('run', 'I run fast.').toList(),
    );
    for (final section in ['## 音标', '## 直译', '## 常见用法', '## 句中含义']) {
      expect(wordPrompt, contains(section));
    }
    expect(wordPrompt, contains('run'));
    expect(wordPrompt, contains('I run fast.'));

    final sentencePrompt = await capturePrompt(
      () => service().analyzeSentenceStream('She said hello.').toList(),
    );
    expect(sentencePrompt, contains('## 翻译'));
    expect(sentencePrompt, contains('## 语法分析'));
    expect(sentencePrompt, contains('She said hello.'));
    expect(sentencePrompt, isNot(contains('原句及翻译')));
  });

  final invalidResponses = <String, String>{
    '提前 EOF': event(content: '残文'),
    '缺少 DONE': '${event(content: '残文')}${event(reason: 'stop')}',
    '缺少 stop': '${event(content: '残文')}data: [DONE]\n\n',
    '长度截断': '${event(content: '残文')}${event(reason: 'length')}data: [DONE]\n\n',
    '内容过滤': '${event(reason: 'content_filter')}data: [DONE]\n\n',
    '损坏 JSON': 'data: {invalid}\n\n',
    '服务错误事件': 'data: {"error":{"message":"failed"}}\n\n',
    '结束后继续输出':
        '${event(reason: 'stop')}${event(content: '残文')}data: [DONE]\n\n',
  };
  for (final entry in invalidResponses.entries) {
    test('${entry.key} 不得正常完成', () async {
      dio.httpClientAdapter = FakeChatAdapter((_) async => body(entry.value));
      await expectLater(
        service().explainWordStream('word', 'context').toList(),
        throwsA(learningError(LearningErrorCode.requestFailed)),
      );
    });
  }

  test('完整但只有空白时返回空结果错误', () async {
    dio.httpClientAdapter = FakeChatAdapter(
      (_) async => body(
        '${event(content: '  ')}${event(reason: 'stop')}data: [DONE]\n\n',
      ),
    );
    await expectLater(
      service().analyzeSentenceStream('Sentence.').toList(),
      throwsA(learningError(LearningErrorCode.emptyResult)),
    );
  });

  test('等待密钥加载后再发出请求，每次请求只读一次', () async {
    final key = Completer<String>();
    var reads = 0;
    final adapter = FakeChatAdapter(
      (_) async => body(
        '${event(content: '解释')}${event(reason: 'stop')}data: [DONE]\n\n',
      ),
    );
    dio.httpClientAdapter = adapter;
    final result = service(
      readApiKey: () {
        reads++;
        return key.future;
      },
    ).analyzeSentenceStream('Sentence.').toList();
    await Future<void>.delayed(Duration.zero);
    expect(adapter.started.isCompleted, isFalse);
    key.complete(' loaded-key ');
    expect(await result, ['解释']);
    expect(reads, 1);
    expect(
      (await adapter.started.future).headers['Authorization'],
      'Bearer loaded-key',
    );
  });

  test('空密钥不发出请求', () async {
    final adapter = FakeChatAdapter((_) async => body(''));
    dio.httpClientAdapter = adapter;
    await expectLater(
      service(readApiKey: () => ' ').analyzeSentenceStream('S.').toList(),
      throwsA(learningError(LearningErrorCode.noDeepSeekApiKey)),
    );
    expect(adapter.started.isCompleted, isFalse);
  });

  test('等待响应头时取消订阅会立即取消 HTTP', () async {
    final response = Completer<ResponseBody>();
    final adapter = FakeChatAdapter((_) => response.future);
    dio.httpClientAdapter = adapter;
    final subscription = service().analyzeSentenceStream('S.').listen((_) {});
    await adapter.started.future;
    await subscription.cancel();
    await adapter.cancelled.future.timeout(const Duration(seconds: 1));
    response.complete(body(''));
  });

  test('正文一直不返回首包时会超时并释放上游', () async {
    final upstreamCancelled = Completer<void>();
    final source = StreamController<Uint8List>(
      onCancel: upstreamCancelled.complete,
    );
    dio.httpClientAdapter = FakeChatAdapter(
      (_) async => ResponseBody(source.stream, 200),
    );
    await expectLater(
      service(
        idleTimeout: const Duration(milliseconds: 20),
      ).analyzeSentenceStream('S.').toList(),
      throwsA(learningError(LearningErrorCode.requestFailed)),
    );
    await upstreamCancelled.future.timeout(const Duration(seconds: 1));
    await source.close();
  });

  for (final complete in [true, false]) {
    test('真实适配器仅在完整响应后写入单词和句子缓存：$complete', () async {
      String responseText() =>
          '${event(content: '解释')}'
          '${complete ? '${event(reason: 'stop')}data: [DONE]\n\n' : ''}';
      final wordCache = InMemoryWordCacheStore();
      final sentenceCache = InMemorySentenceAnalysisStore();
      final client = service();
      final wordRepository = WordRepository(
        FreeDictionaryService(dio: dio),
        client,
        AliyunTTSService(dio: dio),
        wordCache,
        InMemoryAudioFileStore(),
      );
      final sentenceRepository = SentenceRepository(
        client,
        AliyunTTSService(dio: dio),
        sentenceCache,
        InMemorySentencePronunciationStore(),
        InMemoryAudioFileStore(),
      );
      for (final stream in [
        wordRepository.getContentStream(
          const WordLearningQuery(word: 'word', context: 'context'),
        ),
        sentenceRepository.getContentStream(
          const SentenceLearningQuery(sentence: 'Sentence.'),
        ),
      ]) {
        dio.httpClientAdapter = FakeChatAdapter(
          (_) async => body(responseText()),
        );
        if (complete) {
          expect(await stream.toList(), ['解释']);
        } else {
          await expectLater(stream.toList(), throwsA(isA<LearningException>()));
        }
      }
      expect(wordCache.explanations.length, complete ? 1 : 0);
      expect(sentenceCache.analyses.length, complete ? 1 : 0);
    });
  }

  test('已收到响应头但未收到正文时取消，释放正文订阅', () async {
    final listening = Completer<void>();
    final cancelled = Completer<void>();
    final source = StreamController<Uint8List>(
      onListen: listening.complete,
      onCancel: cancelled.complete,
    );
    dio.httpClientAdapter = FakeChatAdapter(
      (_) async => ResponseBody(source.stream, 200),
    );
    final subscription = service().analyzeSentenceStream('S.').listen((_) {});
    await listening.future;
    await subscription.cancel().timeout(const Duration(seconds: 1));
    await cancelled.future.timeout(const Duration(seconds: 1));
    await source.close();
  });

  test('总时限也覆盖等待响应头', () async {
    final response = Completer<ResponseBody>();
    final adapter = FakeChatAdapter((_) => response.future);
    dio.httpClientAdapter = adapter;
    await expectLater(
      service(
        requestTimeout: const Duration(milliseconds: 30),
      ).analyzeSentenceStream('S.').toList(),
      throwsA(learningError(LearningErrorCode.requestFailed)),
    );
    await adapter.cancelled.future.timeout(const Duration(seconds: 1));
    response.complete(body(''));
  });
}
