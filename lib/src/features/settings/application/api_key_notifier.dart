import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_key_notifier.g.dart';

/// AI 服务（DeepSeek / 阿里云 TTS）的 API Key 配置。
///
/// 密钥由用户自己在设置页填写，存于 [FlutterSecureStorage]（系统安全存储），
/// 不写入源码与构建产物，保证开源分发不含任何密钥。
@Riverpod(keepAlive: true)
class ApiKeyNotifier extends _$ApiKeyNotifier {
  static const _kDeepSeekKey = 'api_key_deepseek';
  static const _kAliyunTtsKey = 'api_key_aliyun_tts';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  ApiKeyConfig build() {
    // 启动时异步加载已保存的 Key，加载完成前返回空配置
    _load();
    return const ApiKeyConfig();
  }

  Future<void> _load() async {
    final deepSeekKey = await _storage.read(key: _kDeepSeekKey) ?? '';
    final aliyunTtsKey = await _storage.read(key: _kAliyunTtsKey) ?? '';
    state = ApiKeyConfig(deepSeekKey: deepSeekKey, aliyunTtsKey: aliyunTtsKey);
  }

  /// 保存 DeepSeek API Key（空字符串视为清除）
  Future<void> setDeepSeekKey(String value) async {
    await _storage.write(key: _kDeepSeekKey, value: value);
    state = state.copyWith(deepSeekKey: value);
  }

  /// 保存阿里云 TTS API Key（空字符串视为清除）
  Future<void> setAliyunTtsKey(String value) async {
    await _storage.write(key: _kAliyunTtsKey, value: value);
    state = state.copyWith(aliyunTtsKey: value);
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
