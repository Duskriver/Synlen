import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';

class LearningDetailDialogView extends StatelessWidget {
  final Widget title;
  final LearningDetailState state;
  final ScrollController? scrollController;
  final Future<void> Function() onPlayAudio;
  final String audioTooltip;
  final String audioLabel;
  final String contentUpdateErrorPrefix;
  final String loadingText;

  const LearningDetailDialogView({
    super.key,
    required this.title,
    required this.state,
    required this.scrollController,
    required this.onPlayAudio,
    required this.audioTooltip,
    required this.audioLabel,
    required this.contentUpdateErrorPrefix,
    required this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    final primaryError = state.contentError ?? state.audioError;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: title),
              if (state.isFetchingContent || state.isFetchingAudio)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: _LearningDetailContent(
              state: state,
              primaryError: primaryError,
              scrollController: scrollController,
              onPlayAudio: onPlayAudio,
              audioTooltip: audioTooltip,
              audioLabel: audioLabel,
              contentUpdateErrorPrefix: contentUpdateErrorPrefix,
              loadingText: loadingText,
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningDetailContent extends StatelessWidget {
  final LearningDetailState state;
  final String? primaryError;
  final ScrollController? scrollController;
  final Future<void> Function() onPlayAudio;
  final String audioTooltip;
  final String audioLabel;
  final String contentUpdateErrorPrefix;
  final String loadingText;

  const _LearningDetailContent({
    required this.state,
    required this.primaryError,
    required this.scrollController,
    required this.onPlayAudio,
    required this.audioTooltip,
    required this.audioLabel,
    required this.contentUpdateErrorPrefix,
    required this.loadingText,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state.isLoading && state.content.isEmpty && !state.hasAudio) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (primaryError != null && state.content.isEmpty && !state.hasAudio) {
      return Text(l10n.loadFailed(primaryError!));
    }

    return SingleChildScrollView(
      controller: scrollController,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.hasAudio)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => onPlayAudio(),
                    tooltip: audioTooltip,
                  ),
                  Text(audioLabel),
                ],
              ),
            ),
          if (state.audioError != null && !state.hasAudio)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.audioUnavailable(state.audioError!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.content.isNotEmpty)
            RepaintBoundary(
              child: MarkdownBody(
                data: state.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          if (state.contentError != null && state.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '$contentUpdateErrorPrefix：${state.contentError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state.isFetchingContent && state.content.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(loadingText),
              ),
            ),
        ],
      ),
    );
  }
}
