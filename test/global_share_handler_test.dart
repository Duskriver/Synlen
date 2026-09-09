import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/file_handling/platform_path.dart';
import 'package:synlen/src/core/file_handling/unified_import_service.dart';
import 'package:synlen/src/core/providers/unified_import_service_provider.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/library/application/bookshelf_notifier.dart';
import 'package:synlen/src/features/library/application/library_notifier.dart';
import 'package:synlen/src/features/library/domain/import_progress.dart';
import 'package:synlen/src/features/library/presentation/widgets/progress_dialog.dart';
import 'package:synlen/src/global_share_handler.dart';

/// 只覆写分享链路消费的入口：清缓存。其余方法不会被调用。
class _FakeUnifiedImportService extends UnifiedImportService {
  bool clearedAllCache = false;

  @override
  Future<void> clearAllCache() async => clearedAllCache = true;
}

/// 记录分享链路传入的路径，并立刻以「全部成功」结束，避免真实导入 I/O。
class _FakeLibraryNotifier extends LibraryNotifier {
  final List<List<PlatformPath>> calls = [];

  @override
  Stream<ProgressLog> importPipelineStream(List<PlatformPath> paths) async* {
    calls.add(paths);
    yield ProgressLog('开始导入', ProgressLogType.info);
    yield ImportProgress(
      totalCount: 1,
      currentCount: 1,
      currentFileName: paths.first.name,
      status: ImportStatus.success,
    );
  }
}

/// 记录刷新次数；build 不触碰数据库与 SharedPreferences。
class _FakeBookshelfNotifier extends BookshelfNotifier {
  int refreshCount = 0;

  @override
  Future<BookshelfState> build() async =>
      BookshelfState.bookshelfState(books: const []);

  @override
  Future<void> refresh() async => refreshCount++;
}

void main() {
  testWidgets('分享进入的待处理文件被导入、清空缓存并刷新书架', (tester) async {
    final unified = _FakeUnifiedImportService();
    final library = _FakeLibraryNotifier();
    final bookshelf = _FakeBookshelfNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unifiedImportServiceProvider.overrideWithValue(unified),
          libraryProvider.overrideWith(() => library),
          bookshelfProvider.overrideWith(() => bookshelf),
        ],
        child: MaterialApp(
          navigatorKey: ToastService.navigatorKey,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const GlobalShareHandler(child: Scaffold(body: Text('书架'))),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlobalShareHandler)),
    );
    expect(container.read(pendingRouteFileProvider), isNull);

    container.read(pendingRouteFileProvider.notifier).set('/tmp/分享书.txt');
    await tester.pumpAndSettle();

    // 待处理路径已交给导入管道，且状态被消费
    expect(library.calls, hasLength(1));
    expect(library.calls.single, [const IOSFilePath('/tmp/分享书.txt')]);
    expect(container.read(pendingRouteFileProvider), isNull);
    expect(find.byType(ProgressDialog), findsOneWidget);

    // 导入完成：关闭对话框后执行清缓存与书架刷新
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();

    expect(unified.clearedAllCache, isTrue);
    expect(bookshelf.refreshCount, 1);
  });
}
