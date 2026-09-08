import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service_provider.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service_provider.dart';

part 'cache_cleanup.g.dart';

/// 缓存清理用例（组合面）：一次编排 library 侧（导入临时文件、孤儿书籍 / 封面 /
/// 分享文件、孤儿字体）与 learning 侧（可重建的文本与音频缓存）的清理。
///
/// 跨 feature 编排只允许出现在组合面（ADR-0003）。
@riverpod
class CacheCleanup extends _$CacheCleanup {
  @override
  void build() {}

  /// 清理全部可重建缓存，返回删除项总数（书籍 + 字体 + 音频条目）。
  Future<int> cleanAll() async {
    final storage = ref.read(storageCleanupServiceProvider);
    await storage.cleanCacheFiles();
    final books = await storage.cleanOrphanFiles();
    await storage.cleanShareFiles();
    final fonts = await storage.cleanOrphanFontFiles();
    final audio = await ref
        .read(learningCacheCleanupServiceProvider)
        .cleanAll();
    return books + fonts + audio;
  }
}
