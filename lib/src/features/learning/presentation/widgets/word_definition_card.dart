import 'package:flutter/material.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/learning/application/learning_detail_state.dart';
import 'package:synlen/src/features/learning/domain/word_definition.dart';

import 'learning_detail_dialog_view.dart';

/// 词条按完整区段逐步展示；切换标签不触发新的查询。
class WordDefinitionCard extends StatefulWidget {
  const WordDefinitionCard({
    super.key,
    required this.word,
    required this.state,
    required this.onPlayAudio,
    required this.onRetry,
  });

  final String word;
  final LearningDetailState state;
  final Future<void> Function() onPlayAudio;
  final VoidCallback onRetry;

  @override
  State<WordDefinitionCard> createState() => _WordDefinitionCardState();
}

class _WordDefinitionCardState extends State<WordDefinitionCard> {
  int _selectedTab = 0;

  @override
  void didUpdateWidget(covariant WordDefinitionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word != widget.word) _selectedTab = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = widget.state;
    final definition = state.wordDefinition;
    final summary = definition?.summary;
    final secondary = theme.colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      key: const ValueKey('word-card-scroll'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            summary?.lemma ?? widget.word,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (summary != null && summary.lemma != widget.word) ...[
            const SizedBox(height: 3),
            Text(
              widget.word,
              style: theme.textTheme.titleMedium?.copyWith(color: secondary),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              IconButton.filledTonal(
                tooltip: l10n.pronounceWord(widget.word),
                onPressed: state.hasAudio ? widget.onPlayAudio : null,
                icon: state.isFetchingAudio && !state.hasAudio
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.volume_up_outlined, size: 22),
              ),
              if (summary?.phonetic case final phonetic?)
                Text(
                  phonetic,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: secondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (summary != null)
            Text.rich(
              key: const ValueKey('word-summary'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '${summary.partOfSpeech}  ',
                    style: TextStyle(
                      color: secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  TextSpan(
                    text: '${summary.definitionEn}\n${summary.definitionZh}',
                  ),
                ],
              ),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            )
          else
            _pendingContent(l10n),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tab(0, l10n.wordTabExplanation, 'explanation'),
              _tab(1, l10n.wordTabSynonyms, 'synonyms'),
              _tab(2, l10n.wordTabFormation, 'formation'),
            ],
          ),
          const SizedBox(height: 16),
          DefaultTextStyle(
            style: theme.textTheme.bodyLarge!.copyWith(
              color: secondary,
              height: 1.5,
            ),
            child: _section(definition, l10n),
          ),
          if (state.contentError != null) ...[
            const SizedBox(height: 14),
            _error(
              l10n.loadFailed(
                resolveLearningErrorText(state.contentError, l10n),
              ),
            ),
          ],
          if (state.audioError != null) ...[
            const SizedBox(height: 12),
            _error(
              l10n.audioUnavailable(
                resolveLearningErrorText(state.audioError, l10n),
              ),
            ),
          ],
          if (state.contentError != null || state.audioError != null)
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
        ],
      ),
    );
  }

  Widget _tab(int index, String label, String name) {
    final selected = _selectedTab == index;
    final theme = Theme.of(context);
    return Expanded(
      child: Semantics(
        selected: selected,
        child: InkWell(
          key: ValueKey('word-tab-$name'),
          onTap: () => setState(() => _selectedTab = index),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 2,
                  width: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(WordDefinition? definition, AppLocalizations l10n) {
    switch (_selectedTab) {
      case 0:
        final text = definition?.explanation;
        return text == null
            ? _pendingContent(l10n)
            : Text(text, key: const ValueKey('word-explanation'));
      case 1:
        final synonyms = definition?.synonyms;
        if (synonyms == null) return _pendingContent(l10n);
        return Column(
          key: const ValueKey('word-synonyms'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (synonyms.isEmpty) Text(l10n.wordNoSynonyms),
            for (var i = 0; i < synonyms.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: synonyms[i].word,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text:
                          '  ${synonyms[i].meaning}\n${synonyms[i].distinction}',
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      default:
        final text = definition?.formation;
        return text == null
            ? _pendingContent(l10n)
            : Text(
                text.isEmpty ? l10n.wordNoFormation : text,
                key: const ValueKey('word-formation'),
              );
    }
  }

  Widget _pendingContent(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      widget.state.contentError == null
          ? l10n.wordExplanationLoading
          : l10n.wordSectionUnavailable,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  Widget _error(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
  );
}
