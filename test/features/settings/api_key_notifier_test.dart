import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/settings/application/api_key_notifier.dart';
import 'package:synlen/src/features/settings/data/api_key_storage_provider.dart';

class FakeKeyStorage extends FlutterSecureStorage {
  final values = <String, String>{
    'api_key_deepseek': 'saved-deepseek',
    'api_key_aliyun_tts': 'saved-tts',
  };
  Completer<void>? readGate;
  Completer<void>? writeGate;
  bool failRead = false;
  bool failWrite = false;
  final writes = <String>[];

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = values[key];
    await readGate?.future;
    if (failRead) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes.add(key);
    await writeGate?.future;
    if (failWrite) throw StateError('storage unavailable');
    values[key] = value ?? '';
  }
}

void main() {
  late FakeKeyStorage storage;
  late ProviderContainer container;
  setUp(() {
    storage = FakeKeyStorage();
    container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [apiKeyStorageProvider.overrideWithValue(storage)],
    );
  });

  test('初始化保持加载态，完成后返回两个已保存密钥', () async {
    storage.readGate = Completer<void>();
    expect(container.read(apiKeyProvider).isLoading, isTrue);
    storage.readGate!.complete();
    final config = await container.read(apiKeyProvider.future);
    expect(config.deepSeekKey, 'saved-deepseek');
    expect(config.aliyunTtsKey, 'saved-tts');
  });

  test('首次加载期间保存等待读取，晚到读取不得覆盖新值', () async {
    storage.readGate = Completer<void>();
    final notifier = container.read(apiKeyProvider.notifier);
    final saved = notifier.setDeepSeekKey(' new-key ');
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, isEmpty);
    storage.readGate!.complete();
    expect(await saved, isTrue);
    final config = await container.read(apiKeyProvider.future);
    expect(config.deepSeekKey, 'new-key');
    expect(config.aliyunTtsKey, 'saved-tts');
    expect(storage.values['api_key_deepseek'], 'new-key');
  });

  test('两个字段与连续编辑按调用顺序写入，不丢失其他字段', () async {
    await container.read(apiKeyProvider.future);
    storage.writeGate = Completer<void>();
    final notifier = container.read(apiKeyProvider.notifier);
    final first = notifier.setDeepSeekKey('first');
    final second = notifier.setAliyunTtsKey('tts-new');
    final third = notifier.setDeepSeekKey('last');
    await Future<void>.delayed(Duration.zero);
    expect(storage.writes, ['api_key_deepseek']);
    storage.writeGate!.complete();
    expect(await Future.wait([first, second, third]), [true, true, true]);
    final config = await container.read(apiKeyProvider.future);
    expect(config.deepSeekKey, 'last');
    expect(config.aliyunTtsKey, 'tts-new');
    expect(storage.values['api_key_deepseek'], 'last');
  });

  test('写入失败保留已加载配置，后续保存可重试', () async {
    await container.read(apiKeyProvider.future);
    storage.failWrite = true;
    final notifier = container.read(apiKeyProvider.notifier);
    expect(await notifier.setDeepSeekKey('new'), isFalse);
    expect(
      (await container.read(apiKeyProvider.future)).deepSeekKey,
      'saved-deepseek',
    );
    storage.failWrite = false;
    expect(await notifier.setDeepSeekKey('new'), isTrue);
    expect((await container.read(apiKeyProvider.future)).deepSeekKey, 'new');
  });

  test('读取失败为 error，重新加载可恢复且不伪造空配置', () async {
    storage.failRead = true;
    await expectLater(container.read(apiKeyProvider.future), throwsStateError);
    expect(container.read(apiKeyProvider).hasError, isTrue);
    storage.failRead = false;
    container.invalidate(apiKeyProvider);
    expect(
      (await container.read(apiKeyProvider.future)).aliyunTtsKey,
      'saved-tts',
    );
  });

  test('清除一个密钥保留另一个并持久化空字符串', () async {
    final notifier = container.read(apiKeyProvider.notifier);
    expect(await notifier.setAliyunTtsKey(''), isTrue);
    final config = await container.read(apiKeyProvider.future);
    expect(config.aliyunTtsKey, isEmpty);
    expect(config.deepSeekKey, 'saved-deepseek');
    expect(storage.values['api_key_aliyun_tts'], isEmpty);
  });
}
