import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/features/learning/application/learning_controller.dart';
import 'package:synlen/src/features/learning/domain/learning_query.dart';
import 'word_definition_card.dart';

class WordDefinitionDialog extends ConsumerWidget {
  final String word;
  final String context;

  const WordDefinitionDialog({
    super.key,
    required this.word,
    required this.context,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = learningControllerProvider(
      WordLearningQuery(word: word, context: this.context),
    );

    return WordDefinitionCard(
      word: word,
      state: ref.watch(provider),
      onPlayAudio: ref.read(provider.notifier).playAudio,
      onRetry: ref.read(provider.notifier).retry,
    );
  }
}
