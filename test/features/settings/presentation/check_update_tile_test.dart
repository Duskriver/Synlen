import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/settings/application/update_check.dart';
import 'package:synlen/src/features/settings/domain/version_manifest.dart';
import 'package:synlen/src/features/settings/presentation/widgets/check_update_tile.dart';

class _UpdateCheck extends UpdateCheck {
  final cancellation = Completer<void>();
  final operation = Completer<void>();
  bool cancelCalled = false;

  @override
  AsyncValue<UpdateState> build() => const AsyncValue.data(UpdateState());

  @override
  Future<void> checkForUpdates() async {
    state = const AsyncValue.data(
      UpdateState(
        checkStatus: UpdateCheckStatus.updateAvailable,
        manifest: VersionManifest(
          major: 1,
          minor: 0,
          patch: 0,
          build: 10000,
          androidApkUrl: 'https://example.com/app.apk',
          githubUrl: 'https://example.com/fallback.apk',
        ),
      ),
    );
  }

  @override
  Future<void> downloadAndInstall() async {
    state = AsyncValue.data(
      state.asData!.value.copyWith(
        download: const UpdateDownloadState(
          status: UpdateDownloadStatus.downloading,
        ),
      ),
    );
    await operation.future;
  }

  @override
  Future<void> cancelDownload() async {
    cancelCalled = true;
    state = AsyncValue.data(
      state.asData!.value.copyWith(
        download: const UpdateDownloadState(
          status: UpdateDownloadStatus.canceling,
        ),
      ),
    );
    await cancellation.future;
    state = AsyncValue.data(
      state.asData!.value.copyWith(
        download: const UpdateDownloadState(
          status: UpdateDownloadStatus.canceled,
        ),
      ),
    );
    operation.complete();
  }
}

void main() {
  testWidgets('下载弹窗阻止返回和备用跳转，等待取消确认后关闭', (tester) async {
    final updater = _UpdateCheck();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [updateCheckProvider.overrideWith(() => updater)],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: TargetPlatform.android),
          home: const Scaffold(body: CheckUpdateTile()),
        ),
      ),
    );
    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下载并安装'));
    await tester.pump();
    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(progress.value, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'GitHub 下载'))
          .onPressed,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(updater.cancelCalled, isTrue);
    expect(find.byType(AlertDialog), findsOneWidget);
    updater.cancellation.complete();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
