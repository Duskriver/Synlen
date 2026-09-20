import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/settings/application/deep_seek_connectivity.dart';

/// 连通性检查用例的映射逻辑：data 层的 HTTP 结果 → presentation 可展示的枚举。
void main() {
  ProviderContainer containerWith(HttpClientAdapter adapter) {
    final container = ProviderContainer(
      overrides: [
        deepSeekServiceProvider.overrideWith((ref) {
          final dio = Dio()..httpClientAdapter = adapter;
          ref.onDispose(() => dio.close(force: true));
          return DeepSeekService(dio: dio, readApiKey: () => '');
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<DeepSeekConnectivity?> check(
    ProviderContainer container,
    String key,
  ) async {
    final subscription = container.listen(deepSeekKeyCheckProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(deepSeekKeyCheckProvider.notifier).check(key);
    return container.read(deepSeekKeyCheckProvider).asData?.value;
  }

  test('空密钥不发请求，判定为未配置', () async {
    var called = false;
    final container = containerWith(
      _StubAdapter((_) async {
        called = true;
        return ResponseBody.fromString('{}', 200);
      }),
    );

    expect(await check(container, '   '), DeepSeekConnectivity.notConfigured);
    expect(called, isFalse, reason: '未配置密钥时不得发起网络请求');
  });

  test('200 判定为连通', () async {
    final container = containerWith(
      _StubAdapter((_) async => ResponseBody.fromString('{"data":[]}', 200)),
    );

    expect(await check(container, 'sk-valid'), DeepSeekConnectivity.ok);
  });

  test('401 判定为密钥无效', () async {
    final container = containerWith(
      _StubAdapter((_) async => ResponseBody.fromString('', 401)),
    );

    expect(
      await check(container, 'sk-expired'),
      DeepSeekConnectivity.invalidKey,
    );
  });

  test('网络异常判定为不可达', () async {
    final container = containerWith(
      _StubAdapter(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      ),
    );

    expect(
      await check(container, 'sk-valid'),
      DeepSeekConnectivity.unreachable,
    );
  });

  test('等待响应时禁止重复检查，退出释放客户端且迟到结果不写入状态', () async {
    final response = Completer<ResponseBody>();
    final adapter = _StubAdapter((_) => response.future);
    final container = containerWith(adapter);
    final subscription = container.listen(deepSeekKeyCheckProvider, (_, _) {});
    final notifier = container.read(deepSeekKeyCheckProvider.notifier);
    final first = notifier.check('sk-valid');
    await notifier.check('sk-valid');
    await adapter.started.future;
    await container.pump();
    expect(adapter.calls, 1);
    expect(adapter.closed, isFalse);
    expect(subscription.read().isLoading, isTrue);

    subscription.close();
    await container.pump();
    expect(adapter.closed, isTrue);
    response.complete(ResponseBody.fromString('{"data":[]}', 200));
    await first;
    expect(container.exists(deepSeekKeyCheckProvider), isFalse);
  });
}

/// 固定返回某个响应的 HttpClientAdapter。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  int calls = 0;
  bool closed = false;
  final started = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    if (!started.isCompleted) started.complete();
    return respond(options);
  }

  @override
  void close({bool force = false}) => closed = true;
}
