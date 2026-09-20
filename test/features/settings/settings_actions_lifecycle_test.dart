import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/learning/data/repositories/learning_repository_provider.dart';
import 'package:synlen/src/features/learning/data/services/deep_seek_service.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service.dart';
import 'package:synlen/src/features/learning/data/services/learning_cache_cleanup_service_provider.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service.dart';
import 'package:synlen/src/features/library/data/services/storage_cleanup_service_provider.dart';
import 'package:synlen/src/features/settings/data/api_key_storage_provider.dart';
import 'package:synlen/src/features/settings/presentation/widgets/clean_cache_tile.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_ai_service_section.dart';

import 'api_key_notifier_test.dart' show FakeKeyStorage;

Widget _app(Widget child) => MaterialApp(
  navigatorKey: ToastService.navigatorKey,
  locale: const Locale('zh'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('缓存清理跨帧等待后仍清理学习缓存，并恢复按钮', (tester) async {
    final storage = _StorageCleanup();
    final learning = _LearningCleanup();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageCleanupServiceProvider.overrideWith((ref) {
            ref.onDispose(() => storage.disposed = true);
            return storage;
          }),
          learningCacheCleanupServiceProvider.overrideWith((ref) => learning),
        ],
        child: _app(const CleanCacheTile()),
      ),
    );
    await tester.tap(find.text('清理缓存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(storage.disposed, isFalse);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    storage.gate.complete();
    await tester.pumpAndSettle();
    expect(learning.calls, 1);
    expect(find.text('清理完成，已删除 6 个无用文件'), findsOneWidget);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
    await _dismissToast(tester);
    await tester.pumpWidget(const SizedBox());
    expect(storage.disposed, isTrue);
  });

  testWidgets('缓存清理失败显示可读提示，按钮可重试且不泄露内部错误', (tester) async {
    final storage = _StorageCleanup()..fail = true;
    final learning = _LearningCleanup();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageCleanupServiceProvider.overrideWith((ref) => storage),
          learningCacheCleanupServiceProvider.overrideWith((ref) => learning),
        ],
        child: _app(const CleanCacheTile()),
      ),
    );
    await tester.tap(find.text('清理缓存'));
    storage.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('缓存清理未完成，请重试。'), findsOneWidget);
    expect(find.textContaining('private cache path'), findsNothing);
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
    storage.fail = false;
    await tester.tap(find.text('清理缓存'));
    await tester.pumpAndSettle();
    expect(learning.calls, 1);
    expect(find.text('清理完成，已删除 6 个无用文件'), findsOneWidget);
    await _dismissToast(tester);
  });

  testWidgets('设置页独立检查密钥时持有 HTTP 客户端，离开后释放', (tester) async {
    final adapter = _DelayedAdapter();
    final storage = FakeKeyStorage();
    storage.values['api_key_deepseek'] = 'sk-valid';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiKeyStorageProvider.overrideWithValue(storage),
          deepSeekServiceProvider.overrideWith((ref) {
            final dio = Dio()..httpClientAdapter = adapter;
            ref.onDispose(() => dio.close(force: true));
            return DeepSeekService(dio: dio, readApiKey: () => '');
          }),
        ],
        child: _app(const SettingsAiServiceSection()),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsAiServiceSection)),
    )!;
    await tester.tap(find.text(l10n.deepSeekCheckConnectivity));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(adapter.started, isTrue);
    expect(adapter.closed, isFalse);
    adapter.response.complete(ResponseBody.fromString('{"data":[]}', 200));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deepSeekCheckOk), findsOneWidget);
    expect(find.text(l10n.deepSeekCheckFailed), findsNothing);
    await _dismissToast(tester);
    await tester.pumpWidget(const SizedBox());
    expect(adapter.closed, isTrue);
  });

  testWidgets('密钥检查中离开页面不会提示失败，再次进入使用新的客户端', (tester) async {
    final adapters = <_DelayedAdapter>[];
    final container = ProviderContainer.test(
      overrides: [
        apiKeyStorageProvider.overrideWithValue(FakeKeyStorage()),
        deepSeekServiceProvider.overrideWith((ref) {
          final adapter = _DelayedAdapter();
          adapters.add(adapter);
          final dio = Dio()..httpClientAdapter = adapter;
          ref.onDispose(() => dio.close(force: true));
          return DeepSeekService(dio: dio, readApiKey: () => '');
        }),
      ],
    );
    Future<void> show(Widget child) => tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: _app(child)),
    );

    await show(const SettingsAiServiceSection());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsAiServiceSection)),
    )!;
    await tester.tap(find.text(l10n.deepSeekCheckConnectivity));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(adapters.single.started, isTrue);
    await show(const SizedBox());
    await tester.pumpAndSettle();
    expect(adapters.single.closed, isTrue);
    expect(find.text(l10n.deepSeekCheckFailed), findsNothing);
    expect(tester.takeException(), isNull);

    await show(const SettingsAiServiceSection());
    await tester.pumpAndSettle();
    expect(adapters.length, 2);
    await tester.tap(find.text(l10n.deepSeekCheckConnectivity));
    await tester.pump();
    adapters.last.response.complete(ResponseBody.fromString('{}', 200));
    await tester.pumpAndSettle();
    expect(find.text(l10n.deepSeekCheckOk), findsOneWidget);
    await _dismissToast(tester);
    await show(const SizedBox());
    await tester.pumpAndSettle();
    expect(adapters.every((adapter) => adapter.closed), isTrue);
  });
}

class _StorageCleanup implements StorageCleanupService {
  final gate = Completer<void>();
  bool disposed = false;
  bool fail = false;

  @override
  Future<void> cleanCacheFiles() async {
    await gate.future;
    if (fail) throw const FileSystemException('private cache path');
  }

  @override
  Future<int> cleanOrphanFiles() async => 1;

  @override
  Future<void> cleanShareFiles() async {}

  @override
  Future<int> cleanOrphanFontFiles() async => 2;

  @override
  Future<File> saveTempFileForSharing(File sourceFile, String title) =>
      throw UnimplementedError();
}

class _LearningCleanup implements LearningCacheCleanupService {
  int calls = 0;

  @override
  Future<int> cleanAll() async {
    calls++;
    return 3;
  }
}

class _DelayedAdapter implements HttpClientAdapter {
  final response = Completer<ResponseBody>();
  bool closed = false;
  bool started = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    started = true;
    return response.future;
  }

  @override
  void close({bool force = false}) {
    closed = true;
    if (started && !response.isCompleted) {
      response.completeError(StateError('HTTP client closed during request'));
    }
  }
}
