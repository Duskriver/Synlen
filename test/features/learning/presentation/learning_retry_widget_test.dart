import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart';

void main() {
  final error = StateError('内部细节不得显示');
  for (final state in [
    LearningDetailState(isLoading: false, contentError: error),
    LearningDetailState(isLoading: false, content: '部分解释', contentError: error),
    LearningDetailState(isLoading: false, content: '完整解释', audioError: error),
    const LearningDetailState(isLoading: false, content: '完整解释'),
  ]) {
    testWidgets(
      '学习错误状态可重试：${state.content}/${state.contentError != null}/${state.audioError != null}',
      (tester) async {
        var retries = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: LearningDetailDialogView(
                title: const Text('word'),
                state: state,
                scrollController: null,
                onPlayAudio: () async {},
                onRetry: () => retries++,
                audioTooltip: '发音',
                audioLabel: '发音',
                contentUpdateErrorPrefix: '解释失败',
                loadingText: '加载中',
              ),
            ),
          ),
        );
        if (state.contentError != null || state.audioError != null) {
          await tester.tap(find.text('重试'));
          expect(retries, 1);
        } else {
          expect(find.text('重试'), findsNothing);
        }
        expect(find.textContaining('内部细节不得显示'), findsNothing);
      },
    );
  }
}
