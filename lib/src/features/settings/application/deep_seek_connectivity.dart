import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';

part 'deep_seek_connectivity.g.dart';

/// 连通性检查的可展示结果。
enum DeepSeekConnectivity { ok, notConfigured, invalidKey, unreachable }

/// DeepSeek 密钥连通性检查用例（组合面）：把 data 层的 HTTP 异常翻译成
/// presentation 可直接映射 l10n 的结果，UI 不再 import Dio。
@riverpod
class DeepSeekKeyCheck extends _$DeepSeekKeyCheck {
  @override
  AsyncValue<DeepSeekConnectivity?> build() {
    // HTTP 客户端必须覆盖异步请求的等待期，并随最后一个订阅者退出释放。
    ref.watch(deepSeekServiceProvider);
    return const AsyncValue.data(null);
  }

  Future<void> check(String apiKey) async {
    if (state.isLoading) return;
    if (apiKey.trim().isEmpty) {
      state = const AsyncValue.data(DeepSeekConnectivity.notConfigured);
      return;
    }
    state = const AsyncValue.loading();
    DeepSeekConnectivity outcome;
    try {
      await ref.read(deepSeekServiceProvider).verifyApiKey(apiKey);
      outcome = DeepSeekConnectivity.ok;
    } on DioException catch (error) {
      outcome = error.response?.statusCode == 401
          ? DeepSeekConnectivity.invalidKey
          : DeepSeekConnectivity.unreachable;
    } catch (_) {
      outcome = DeepSeekConnectivity.unreachable;
    }
    if (!ref.mounted) return;
    state = AsyncValue.data(outcome);
  }
}
