import 'dart:async';
import 'dart:convert';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/aliyun_tts_service.dart';
import 'package:synlen/src/features/settings/application/api_key_notifier.dart';
import 'package:synlen/src/features/settings/data/api_key_storage_provider.dart';

import 'api_key_notifier_test.dart' show FakeKeyStorage;
import '../learning/data/services/deep_seek_service_test.dart'
    show FakeChatAdapter, body, event;

void main() {
  test('等待密钥期间取消 TTS，加载完成后不得读取音色或发起 HTTP', () async {
    final key = Completer<String>();
    final dio = Dio();
    addTearDown(() => dio.close(force: true));
    final adapter = FakeChatAdapter((_) async => body(''));
    dio.httpClientAdapter = adapter;
    final cancellation = LearningCancellation();
    final result = expectLater(
      AliyunTTSService(
        dio: dio,
        readApiKey: () => key.future,
        readVoiceParam: () => throw StateError('不得读取已销毁的音色配置'),
      ).generateAudioStream('word', cancellation: cancellation).toList(),
      throwsA(isA<LearningCancelled>()),
    );
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    key.complete('saved-key');
    await result;
    expect(adapter.started.isCompleted, isFalse);
  });

  test('冷启动直接查询时，两个真实服务适配器等候安全存储后使用各自密钥', () async {
    final storage = FakeKeyStorage()..readGate = Completer<void>();
    final container = ProviderContainer.test(
      overrides: [apiKeyStorageProvider.overrideWithValue(storage)],
    );
    final textDio = Dio();
    final ttsDio = Dio();
    addTearDown(() {
      textDio.close(force: true);
      ttsDio.close(force: true);
    });
    final textAdapter = FakeChatAdapter(
      (_) async => body(
        '${event(content: '解释')}${event(reason: 'stop')}data: [DONE]\n\n',
      ),
    );
    final ttsAdapter = FakeChatAdapter(
      (_) async => body(
        'data: ${jsonEncode({
          'output': {
            'audio': {
              'data': base64Encode([0, 0]),
            },
          },
        })}\n\n',
      ),
    );
    textDio.httpClientAdapter = textAdapter;
    ttsDio.httpClientAdapter = ttsAdapter;
    final explanation = DeepSeekService(
      dio: textDio,
      readApiKey: () async =>
          (await container.read(apiKeyProvider.future)).deepSeekKey,
    ).explainWordStream('word', 'context').toList();
    final audio = AliyunTTSService(
      dio: ttsDio,
      readApiKey: () async =>
          (await container.read(apiKeyProvider.future)).aliyunTtsKey,
    ).generateAudioStream('word').toList();
    await Future<void>.delayed(Duration.zero);
    expect(textAdapter.started.isCompleted, isFalse);
    expect(ttsAdapter.started.isCompleted, isFalse);
    storage.readGate!.complete();
    expect(await explanation, ['解释']);
    expect(await audio, [
      [0, 0],
    ]);
    expect(
      (await textAdapter.started.future).headers['Authorization'],
      'Bearer saved-deepseek',
    );
    expect(
      (await ttsAdapter.started.future).headers['Authorization'],
      'Bearer saved-tts',
    );
  });
}
