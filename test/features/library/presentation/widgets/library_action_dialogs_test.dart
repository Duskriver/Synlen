import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/library/presentation/widgets/delete_books_confirm_dialog.dart';
import 'package:synlen/src/features/library/presentation/widgets/group_name_prompt_dialog.dart';
import 'package:synlen/src/features/library/presentation/widgets/restore_source_dialog.dart';

void main() {
  /// 打开 [dialog] 并返回其结果；[tap] 指定点击的按钮。
  Future<T?> openDialog<T>(
    WidgetTester tester,
    Widget dialog, {
    required Future<void> Function(WidgetTester tester) tap,
  }) async {
    T? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<T>(
                    context: context,
                    builder: (_) => dialog,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tap(tester);
    await tester.pumpAndSettle();
    return result;
  }

  group('DeleteBooksConfirmDialog', () {
    testWidgets('确认返回 true', (tester) async {
      final result = await openDialog<bool>(
        tester,
        const DeleteBooksConfirmDialog(),
        tap: (tester) async => tester.tap(find.byType(FilledButton)),
      );

      expect(result, isTrue);
    });

    testWidgets('取消返回 false', (tester) async {
      final result = await openDialog<bool>(
        tester,
        const DeleteBooksConfirmDialog(),
        tap: (tester) async => tester.tap(find.byType(TextButton)),
      );

      expect(result, isFalse);
    });
  });

  group('GroupNamePromptDialog', () {
    testWidgets('创建返回 trim 后的名称', (tester) async {
      final result = await openDialog<String>(
        tester,
        const GroupNamePromptDialog(),
        tap: (tester) async {
          await tester.enterText(find.byType(TextField), '  科幻  ');
          await tester.tap(find.byType(FilledButton));
        },
      );

      expect(result, '科幻');
    });

    testWidgets('取消返回 null', (tester) async {
      final result = await openDialog<String>(
        tester,
        const GroupNamePromptDialog(),
        tap: (tester) async => tester.tap(find.byType(TextButton)),
      );

      expect(result, isNull);
    });
  });

  group('RestoreSourceDialog', () {
    testWidgets('选择文件夹', (tester) async {
      final result = await openDialog<RestoreBackupSource>(
        tester,
        const RestoreSourceDialog(),
        tap: (tester) async => tester.tap(find.byType(TextButton)),
      );

      expect(result, RestoreBackupSource.folder);
    });

    testWidgets('选择 ZIP 文件', (tester) async {
      final result = await openDialog<RestoreBackupSource>(
        tester,
        const RestoreSourceDialog(),
        tap: (tester) async => tester.tap(find.byType(FilledButton)),
      );

      expect(result, RestoreBackupSource.zipFile);
    });
  });
}
