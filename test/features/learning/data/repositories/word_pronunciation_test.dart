import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/repositories/word_repository.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/free_dictionary_service.dart';
import 'package:synlen/src/features/learning/domain/audio_stream_result.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

import 'learning_repository_test.dart'
    show
        FakeAliyunTTSService,
        InMemoryAudioFileStore,
        InMemoryWordCacheStore,
        testDio;

class _AudioAdapter implements HttpClientAdapter {
  _AudioAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  final cancelledRequests = <RequestOptions>[];
  var cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    cancelFuture?.then((_) {
      cancelled = true;
      cancelledRequests.add(options);
    });
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

const _mp3Bytes = <int>[0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0];

ResponseBody _audioBody(List<int> bytes, {String type = 'audio/mpeg'}) {
  return ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentTypeHeader: [type],
    },
  );
}

WordRepository _repository(_AudioAdapter adapter) {
  final dio = testDio()..httpClientAdapter = adapter;
  return WordRepository(
    FreeDictionaryService(dio: dio),
    DeepSeekService(dio: testDio()),
    FakeAliyunTTSService(const [
      [0, 0, 1, 0],
    ]),
    InMemoryWordCacheStore(),
    InMemoryAudioFileStore(),
  );
}

void main() {
  test('原词直接请求有道美音，完整 MP3 交给缓存且无需二次远程播放', () async {
    final adapter = _AudioAdapter((request) async {
      if (request.uri.host != 'dict.youdao.com') {
        return ResponseBody.fromString('unavailable', 503);
      }
      return _audioBody(_mp3Bytes);
    });
    const word = "reader's";
    final result = await _repository(
      adapter,
    ).getPronunciationStream(word).first;

    expect(result.format, AudioFormat.mp3);
    expect(result.cacheByVoice, isFalse);
    expect(result.playbackUri, isNull);
    expect(await result.stream.expand((bytes) => bytes).toList(), _mp3Bytes);
    expect(adapter.requests, hasLength(1));
    final uri = adapter.requests.single.uri;
    expect(uri.scheme, 'https');
    expect(uri.path, '/dictvoice');
    expect(uri.queryParameters, {'audio': word, 'type': '2'});
  });

  for (final responseHasStarted in [false, true]) {
    test('词典${responseHasStarted ? '正文' : '响应头'}卡住时两秒内终止下载并回退 TTS', () {
      fakeAsync((async) {
        final pending = Completer<ResponseBody>();
        var bodyCancelled = false;
        final body = StreamController<Uint8List>(
          onCancel: () => bodyCancelled = true,
        );
        final adapter = _AudioAdapter(
          (_) => responseHasStarted
              ? Future.value(
                  ResponseBody(
                    body.stream,
                    200,
                    headers: {
                      Headers.contentTypeHeader: ['audio/mpeg'],
                    },
                  ),
                )
              : pending.future,
        );
        AudioStreamResult? result;
        _repository(adapter).getPronunciationStream('word').first.then((value) {
          result = value;
        });
        async.flushMicrotasks();
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1999));
        expect(result, isNull);
        async.elapse(const Duration(milliseconds: 1));
        expect(result?.format, AudioFormat.pcm);
        expect(adapter.cancelled, isTrue);
        if (responseHasStarted) expect(bodyCancelled, isTrue);
        pending.complete(_audioBody(_mp3Bytes));
        body.close();
        async.flushMicrotasks();
      });
    });
  }

  test('收取词典正文期间关闭查询，释放响应且不回退 TTS', () async {
    final listening = Completer<void>();
    final cancelled = Completer<void>();
    final body = StreamController<Uint8List>(
      onListen: listening.complete,
      onCancel: cancelled.complete,
    );
    final adapter = _AudioAdapter(
      (_) async => ResponseBody(
        body.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['audio/mpeg'],
        },
      ),
    );
    final cancellation = LearningCancellation();
    final result = expectLater(
      _repository(
        adapter,
      ).getPronunciationStream('word', cancellation: cancellation).toList(),
      throwsA(isA<LearningCancelled>()),
    );
    await listening.future;
    body.add(Uint8List.fromList(_mp3Bytes));
    cancellation.cancel();
    await result;
    await cancelled.future.timeout(const Duration(seconds: 1));
    expect(adapter.cancelled, isTrue);
    await body.close();
  });

  test('共用词典客户端时取消前一查询，后一查询仍返回完整 MP3', () async {
    final pending = <String, Completer<ResponseBody>>{};
    final adapter = _AudioAdapter((request) {
      final response = Completer<ResponseBody>();
      pending[request.uri.queryParameters['audio']!] = response;
      return response.future;
    });
    final repository = _repository(adapter);
    final cancellation = LearningCancellation();
    final first = expectLater(
      repository
          .getPronunciationStream('first', cancellation: cancellation)
          .toList(),
      throwsA(isA<LearningCancelled>()),
    );
    final second = repository.getPronunciationStream('second').first;
    while (pending.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    cancellation.cancel();
    await first;
    expect(
      adapter.cancelledRequests.map(
        (request) => request.uri.queryParameters['audio'],
      ),
      ['first'],
    );
    pending['first']!.complete(_audioBody(_mp3Bytes));
    pending['second']!.complete(_audioBody(_mp3Bytes));
    final result = await second;
    expect(result.format, AudioFormat.mp3);
    expect(await result.stream.expand((bytes) => bytes).toList(), _mp3Bytes);
  });

  for (final invalid in [
    (bytes: <int>[60, 104, 116, 109, 108, 62], type: 'text/html'),
    (bytes: <int>[], type: 'audio/mpeg'),
  ]) {
    test(
      '不把 ${invalid.type} 的 ${invalid.bytes.length} 字节错误响应缓存为 MP3',
      () async {
        final adapter = _AudioAdapter(
          (_) async => _audioBody(invalid.bytes, type: invalid.type),
        );
        final result = await _repository(
          adapter,
        ).getPronunciationStream('word').first;
        expect(result.format, AudioFormat.pcm);
        expect(result.cacheByVoice, isTrue);
        expect(await result.stream.expand((bytes) => bytes).toList(), [
          0,
          0,
          1,
          0,
        ]);
      },
    );
  }
}
