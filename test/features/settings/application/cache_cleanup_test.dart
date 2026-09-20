import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service_provider.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service_provider.dart';
import 'package:synlen/src/features/settings/application/cache_cleanup.dart';

void main() {
  late _StorageCleanup storage;
  late _LearningCleanup learning;
  late ProviderContainer container;

  setUp(() {
    storage = _StorageCleanup();
    learning = _LearningCleanup();
    container = ProviderContainer.test(
      overrides: [
        storageCleanupServiceProvider.overrideWith((ref) {
          ref.onDispose(() => storage.disposed = true);
          return storage;
        }),
        learningCacheCleanupServiceProvider.overrideWith((ref) {
          ref.onDispose(() => learning.disposed = true);
          return learning;
        }),
      ],
    );
  });

  test('同一轮清理不重复执行，并统计全部阶段删除量', () async {
    final subscription = container.listen(cacheCleanupProvider, (_, _) {});
    addTearDown(subscription.close);
    final cleanup = container.read(cacheCleanupProvider.notifier);
    final first = cleanup.cleanAll();
    await cleanup.cleanAll();
    await container.pump();
    expect(storage.calls, ['cache']);
    expect(storage.disposed, isFalse);
    expect(learning.disposed, isFalse);
    expect(subscription.read().isLoading, isTrue);
    storage.gate.complete();
    await first;
    expect(storage.calls, ['cache', 'books', 'share', 'fonts']);
    expect(learning.calls, 1);
    expect(subscription.read().asData?.value, 6);
  });

  test('学习缓存失败转成错误状态，随后可重新清理', () async {
    final subscription = container.listen(cacheCleanupProvider, (_, _) {});
    addTearDown(subscription.close);
    learning.fail = true;
    storage.gate.complete();
    final cleanup = container.read(cacheCleanupProvider.notifier);
    await cleanup.cleanAll();
    expect(subscription.read().hasError, isTrue);
    expect(subscription.read().isLoading, isFalse);
    learning.fail = false;
    await cleanup.cleanAll();
    expect(subscription.read().asData?.value, 6);
    expect(learning.calls, 2);
  });

  for (final fail in [false, true]) {
    test('离开页面后释放依赖，当前文件操作${fail ? '失败' : '成功'}不启动后续阶段', () async {
      final subscription = container.listen(cacheCleanupProvider, (_, _) {});
      storage.fail = fail;
      final pending = container.read(cacheCleanupProvider.notifier).cleanAll();
      subscription.close();
      await container.pump();
      expect(storage.disposed, isTrue);
      expect(learning.disposed, isTrue);
      storage.gate.complete();
      await pending;
      expect(storage.calls, ['cache']);
      expect(learning.calls, 0);
      expect(container.exists(cacheCleanupProvider), isFalse);
    });
  }
}

class _StorageCleanup implements StorageCleanupService {
  final gate = Completer<void>();
  final calls = <String>[];
  bool disposed = false;
  bool fail = false;

  @override
  Future<void> cleanCacheFiles() async {
    calls.add('cache');
    await gate.future;
    if (fail) throw const FileSystemException('cache unavailable');
  }

  @override
  Future<int> cleanOrphanFiles() async {
    calls.add('books');
    return 1;
  }

  @override
  Future<void> cleanShareFiles() async => calls.add('share');

  @override
  Future<int> cleanOrphanFontFiles() async {
    calls.add('fonts');
    return 2;
  }

  @override
  Future<File> saveTempFileForSharing(File sourceFile, String title) =>
      throw UnimplementedError();
}

class _LearningCleanup implements LearningCacheCleanupService {
  bool disposed = false;
  bool fail = false;
  int calls = 0;

  @override
  Future<int> cleanAll() async {
    calls++;
    if (fail) throw StateError('database unavailable');
    return 3;
  }
}
