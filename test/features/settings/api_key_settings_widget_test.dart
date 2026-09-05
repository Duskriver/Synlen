import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/settings/data/api_key_storage_provider.dart';
import 'package:synlen/src/features/settings/presentation/widgets/api_key_dialog.dart';
import 'package:synlen/src/features/settings/presentation/widgets/settings_ai_service_section.dart';

import 'api_key_notifier_test.dart' show FakeKeyStorage;

Widget app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('加载期间不显示未配置，读取失败可在设置中重试', (tester) async {
    final storage = FakeKeyStorage()
      ..readGate = Completer<void>()
      ..failRead = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiKeyStorageProvider.overrideWithValue(storage)],
        child: app(const SettingsAiServiceSection()),
      ),
    );
    expect(find.text('加载中'), findsOneWidget);
    expect(find.textContaining('未配置'), findsNothing);
    storage.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('无法读取已保存的密钥，请重试。'), findsOneWidget);
    storage.failRead = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('无法读取已保存的密钥，请重试。'), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
  });

  testWidgets('保存中禁止重复提交，失败保留输入且可重试', (tester) async {
    final save = Completer<bool>();
    var calls = 0;
    await tester.pumpWidget(
      app(
        ApiKeyDialog(
          title: 'DeepSeek',
          providerName: 'DeepSeek',
          initialValue: 'old',
          onSave: (_) {
            calls++;
            return save.future;
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'new');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    expect(calls, 1);
    save.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('密钥保存失败，请重试。'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'new',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('保存尚未完成时销毁对话框，晚到结果不更新已卸载状态', (tester) async {
    final save = Completer<bool>();
    await tester.pumpWidget(
      app(
        ApiKeyDialog(
          title: 'DeepSeek',
          providerName: 'DeepSeek',
          initialValue: '',
          onSave: (_) => save.future,
        ),
      ),
    );
    await tester.tap(find.text('保存'));
    await tester.pumpWidget(const SizedBox());
    save.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
