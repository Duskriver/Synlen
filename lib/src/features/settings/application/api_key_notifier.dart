import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/settings/data/api_key_storage_provider.dart';

part 'api_key_notifier.g.dart';

Duration? _noApiKeyRetry(int retryCount, Object error) => null;

/// 密钥加载完成前保持 loading；读取失败不得冒充空配置。
@Riverpod(keepAlive: true, retry: _noApiKeyRetry)
class ApiKeyNotifier extends _$ApiKeyNotifier {
  static const _kDeepSeekKey = 'api_key_deepseek';
  static const _kAliyunTtsKey = 'api_key_aliyun_tts';
  Future<void> _writes = Future.value();

  @override
  Future<ApiKeyConfig> build() {
    final storage = ref.watch(apiKeyStorageProvider);
    return _load(storage.read);
  }

  Future<ApiKeyConfig> _load(
    Future<String?> Function({required String key}) read,
  ) async {
    final deepSeekKey = await read(key: _kDeepSeekKey) ?? '';
    final aliyunTtsKey = await read(key: _kAliyunTtsKey) ?? '';
    return ApiKeyConfig(deepSeekKey: deepSeekKey, aliyunTtsKey: aliyunTtsKey);
  }

  /// 等待初始化并按调用顺序保存；空字符串清除，失败保留原值并返回 false。
  Future<bool> setDeepSeekKey(String value) => _save(value, deepSeek: true);

  /// 保存或清除 TTS 密钥，采用与 [setDeepSeekKey] 相同的顺序和失败约定。
  Future<bool> setAliyunTtsKey(String value) => _save(value, deepSeek: false);

  Future<bool> _save(String value, {required bool deepSeek}) {
    final owner = ref;
    final operation = _writes.then((_) async {
      try {
        final config = await future;
        if (!owner.mounted) return false;
        final normalized = value.trim();
        await owner
            .read(apiKeyStorageProvider)
            .write(
              key: deepSeek ? _kDeepSeekKey : _kAliyunTtsKey,
              value: normalized,
            );
        if (!owner.mounted) return false;
        state = AsyncData(
          deepSeek
              ? config.copyWith(deepSeekKey: normalized)
              : config.copyWith(aliyunTtsKey: normalized),
        );
        return true;
      } catch (_) {
        // 不记录平台异常正文，避免第三方错误包含密钥。
        appLogger.w('API Key storage write failed');
        return false;
      }
    });
    _writes = operation.then((_) {});
    return operation;
  }
}

/// AI 服务 API Key 配置快照
class ApiKeyConfig {
  const ApiKeyConfig({this.deepSeekKey = '', this.aliyunTtsKey = ''});

  final String deepSeekKey;
  final String aliyunTtsKey;

  ApiKeyConfig copyWith({String? deepSeekKey, String? aliyunTtsKey}) {
    return ApiKeyConfig(
      deepSeekKey: deepSeekKey ?? this.deepSeekKey,
      aliyunTtsKey: aliyunTtsKey ?? this.aliyunTtsKey,
    );
  }
}
