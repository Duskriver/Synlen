import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';

part 'deep_seek_connectivity.g.dart';

/// 连通性检查的三种可展示结果。
enum DeepSeekConnectivity { ok, notConfigured, invalidKey, unreachable }

/// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
/// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。
@riverpod
class DeepSeekKeyCheck extends _$DeepSeekKeyCheck {
  @override
  void build() {}

  Future<DeepSeekConnectivity> check(String apiKey) async {
    if (apiKey.trim().isEmpty) {
      return DeepSeekConnectivity.notConfigured;
    }
    try {
      await ref.read(deepSeekServiceProvider).verifyApiKey(apiKey);
      return DeepSeekConnectivity.ok;
    } on DioException catch (error) {
      return error.response?.statusCode == 401
          ? DeepSeekConnectivity.invalidKey
          : DeepSeekConnectivity.unreachable;
    } catch (_) {
      return DeepSeekConnectivity.unreachable;
    }
  }
}
