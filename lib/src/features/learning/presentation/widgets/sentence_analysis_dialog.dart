import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/sentence_learning_controller.dart';
import 'package:synlen/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart';

class SentenceAnalysisDialog extends ConsumerWidget {
  final String sentence;
  final ScrollController? scrollController;

  const SentenceAnalysisDialog({
    super.key,
    required this.sentence,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = sentenceLearningControllerProvider(sentence);

    return LearningDetailDialogView(
      title: Text(
        l10n.sentenceAnalysis,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      // 原句本地立即展示，不等待也不依赖模型输出。
      header: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.originalSentence,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(sentence, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
      state: ref.watch(provider),
      scrollController: scrollController,
      onPlayAudio: ref.read(provider.notifier).playAudio,
      onRetry: ref.read(provider.notifier).retry,
      audioTooltip: l10n.playAudio,
      audioLabel: l10n.readSentenceAloud,
      contentUpdateErrorPrefix: l10n.analysisUpdateFailed,
      loadingText: l10n.sentenceAnalyzing,
    );
  }
}
