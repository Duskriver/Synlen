import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service.dart';
import 'package:synlen/src/features/library/data/services/export_backup_service_provider.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';
import 'package:synlen/src/features/settings/presentation/widgets/backup_tile.dart';

class _Exporter implements ExportBackupService {
  final ExportResult? result;

  _Exporter([this.result]);

  @override
  Future<ExportResult> exportLibraryAsFile({
    Rect? sharePositionOrigin,
    required String shareTitle,
  }) async =>
      result ?? (throw const FileSystemException('private device path'));

  @override
  Future<void> clearCache() async {}
}

void main() {
  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets('$locale 备份异常显示本地化提示，按钮可重试且无内部细节', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportBackupServiceProvider.overrideWithValue(_Exporter()),
          ],
          child: MaterialApp(
            navigatorKey: ToastService.navigatorKey,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BackupTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('private device path'), findsNothing);
      expect(
        find.text(
          locale.languageCode == 'zh'
              ? '备份导出失败，请重试。'
              : 'Could not export the backup. Please try again.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('$locale 取消备份显示本地化提示且按钮可重试', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            exportBackupServiceProvider.overrideWithValue(
              _Exporter(const ExportFailure(LibraryErrorCode.exportCancelled)),
            ),
          ],
          child: MaterialApp(
            navigatorKey: ToastService.navigatorKey,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: BackupTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text(
          locale.languageCode == 'zh' ? '已取消备份导出。' : 'Backup export cancelled.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  }
}
