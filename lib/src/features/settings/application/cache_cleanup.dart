import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service_provider.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service_provider.dart';

part 'cache_cleanup.g.dart';

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 页面订阅用例，用例订阅服务；退出后不再启动后续清理阶段。
@riverpod
class CacheCleanup extends _$CacheCleanup {
  @override
  AsyncValue<int?> build() {
    ref.watch(storageCleanupServiceProvider);
    ref.watch(learningCacheCleanupServiceProvider);
    return const AsyncValue.data(null);
  }

  /// 成功状态携带删除项总数；失败保留错误状态，允许重新清理。
  Future<void> cleanAll() async {
    if (state.isLoading) return;
    state = const AsyncValue.loading();
    try {
      final storage = ref.read(storageCleanupServiceProvider);
      await storage.cleanCacheFiles();
      if (!ref.mounted) return;
      final books = await storage.cleanOrphanFiles();
      if (!ref.mounted) return;
      await storage.cleanShareFiles();
      if (!ref.mounted) return;
      final fonts = await storage.cleanOrphanFontFiles();
      if (!ref.mounted) return;
      final audio = await ref
          .read(learningCacheCleanupServiceProvider)
          .cleanAll();
      if (!ref.mounted) return;
      state = AsyncValue.data(books + fonts + audio);
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      appLogger.e('缓存清理失败', error: error, stackTrace: stackTrace);
      state = AsyncValue.error(error, stackTrace);
    }
  }
}
