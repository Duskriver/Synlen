import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final provider = sentenceLearningControllerProvider(sentence);

    return LearningDetailDialogView(
      title: Text('句子分析', style: Theme.of(context).textTheme.headlineSmall),
      state: ref.watch(provider),
      scrollController: scrollController,
      onPlayAudio: ref.read(provider.notifier).playAudio,
      audioTooltip: '播放音频',
      audioLabel: '朗读句子',
      contentUpdateErrorPrefix: '分析更新失败',
      loadingText: '正在分析...',
    );
  }
}
