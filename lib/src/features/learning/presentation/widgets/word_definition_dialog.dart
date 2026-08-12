import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/word_learning_controller.dart';
import 'package:synlen/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart';

class WordDefinitionDialog extends ConsumerWidget {
  final String word;
  final String context;
  final ScrollController? scrollController;

  const WordDefinitionDialog({
    super.key,
    required this.word,
    required this.context,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final provider = wordLearningControllerProvider(
      WordLearningRequest(word: word, context: this.context),
    );

    return LearningDetailDialogView(
      title: Text(
        word,
        style: Theme.of(context).textTheme.headlineSmall,
        overflow: TextOverflow.ellipsis,
      ),
      state: ref.watch(provider),
      scrollController: scrollController,
      onPlayAudio: ref.read(provider.notifier).playAudio,
      audioTooltip: l10n.playPronunciation,
      audioLabel: l10n.playPronunciation,
      contentUpdateErrorPrefix: l10n.definitionUpdateFailed,
      loadingText: l10n.wordExplanationLoading,
    );
  }
}
