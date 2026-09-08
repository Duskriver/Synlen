import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/services/toast_service.dart';
import 'package:synlen/src/core/widgets/toast_bubble.dart';
import 'package:synlen/src/features/library/domain/import_progress.dart';
import 'package:synlen/src/features/library/presentation/widgets/progress_dialog.dart';
import 'package:synlen/src/features/library/presentation/widgets/restore_progress_dialog.dart';

void main() {
  Future<AppLocalizations> showRestore(
    WidgetTester tester,
    Stream<ProgressLog> stream,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: ToastService.navigatorKey,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: RestoreProgressDialog(
              stream: stream,
              l10n: AppLocalizations.of(context)!,
            ),
          ),
        ),
      ),
    );
    return AppLocalizations.of(
      tester.element(find.byType(RestoreProgressDialog)),
    )!;
  }

  Future<void> clearToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('全部书籍成功后仍等流结束，随后显示成功', (tester) async {
    final controller = StreamController<ProgressLog>();
    final l10n = await showRestore(tester, controller.stream);
    controller.add(
      BackupImportProgress(
        current: 1,
        total: 1,
        currentFileName: '测试书',
        result: const ImportSuccess(importedBooks: 1),
      ),
    );
    await tester.pump();
    expect(
      tester.widget<ProgressDialog>(find.byType(ProgressDialog)).isCompleted,
      isFalse,
    );
    await controller.close();
    await tester.pump();
    final dialog = tester.widget<ProgressDialog>(find.byType(ProgressDialog));
    expect(dialog.isCompleted, isTrue);
    expect(dialog.completeTitle, l10n.restoreCompleted);
    expect(dialog.progressMessage, l10n.restoringProgress(1, 0, 0));
    expect(
      tester.widget<ToastBubble>(find.byType(ToastBubble)).type,
      ToastBubbleType.success,
    );
    await clearToast(tester);
  });

  testWidgets('部分成功后失败不得显示恢复完成或全部处理完成', (tester) async {
    final controller = StreamController<ProgressLog>();
    final l10n = await showRestore(tester, controller.stream);
    controller.add(
      BackupImportProgress(
        current: 1,
        total: 3,
        currentFileName: '第一本',
        result: const ImportSuccess(importedBooks: 1),
      ),
    );
    controller.add(
      BackupImportProgress(
        current: 1,
        total: 3,
        currentFileName: '第二本',
        result: const ImportFailure('写入失败'),
      ),
    );
    await controller.close();
    await tester.pump();
    final dialog = tester.widget<ProgressDialog>(find.byType(ProgressDialog));
    expect(dialog.isCompleted, isTrue);
    expect(dialog.completeTitle, l10n.restoreIncomplete);
    expect(dialog.progressMessage, l10n.restoringProgress(1, 1, 1));
    expect(find.text(l10n.restoreCompleted), findsNothing);
    expect(find.text(l10n.progressedAll), findsNothing);
    expect(
      tester.widget<ToastBubble>(find.byType(ToastBubble)).type,
      ToastBubbleType.error,
    );
    await clearToast(tester);
  });

  testWidgets('读取元数据失败不显示负数剩余量或继续转圈', (tester) async {
    final controller = StreamController<ProgressLog>();
    final l10n = await showRestore(tester, controller.stream);
    controller.add(
      BackupImportProgress(
        current: 0,
        total: 0,
        currentFileName: '',
        result: const ImportFailure('无法读取元数据'),
      ),
    );
    await controller.close();
    await tester.pump();
    final dialog = tester.widget<ProgressDialog>(find.byType(ProgressDialog));
    expect(dialog.progressMessage, l10n.restoringProgress(0, 0, 0));
    expect(dialog.completeTitle, l10n.restoreIncomplete);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await clearToast(tester);
  });

  testWidgets('流异常后 onDone 不得再通知成功', (tester) async {
    final controller = StreamController<ProgressLog>();
    final l10n = await showRestore(tester, controller.stream);
    controller.addError(StateError('private database details'));
    await controller.close();
    await tester.pump();
    expect(find.text(l10n.restoreCompleted), findsNothing);
    expect(find.textContaining('private database details'), findsNothing);
    expect(
      tester.widget<ToastBubble>(find.byType(ToastBubble)).type,
      ToastBubbleType.error,
    );
    await clearToast(tester);
  });
}
