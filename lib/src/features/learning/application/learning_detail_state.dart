import 'package:flutter/foundation.dart';
import 'package:synlen/src/features/learning/domain/word_definition.dart';

@immutable
class LearningDetailState {
  final bool isLoading;
  final bool isFetchingContent;
  final bool isFetchingAudio;
  final String content;
  final WordDefinition? wordDefinition;
  final String? audioUrl;
  final Object? contentError;
  final Object? audioError;
  final bool hasAudio;

  const LearningDetailState({
    this.isLoading = true,
    this.isFetchingContent = false,
    this.isFetchingAudio = false,
    this.content = '',
    this.wordDefinition,
    this.audioUrl,
    this.contentError,
    this.audioError,
    this.hasAudio = false,
  });

  LearningDetailState copyWith({
    bool? isLoading,
    bool? isFetchingContent,
    bool? isFetchingAudio,
    String? content,
    WordDefinition? wordDefinition,
    String? audioUrl,
    bool clearAudioUrl = false,
    Object? contentError,
    bool clearContentError = false,
    Object? audioError,
    bool clearAudioError = false,
    bool? hasAudio,
  }) {
    return LearningDetailState(
      isLoading: isLoading ?? this.isLoading,
      isFetchingContent: isFetchingContent ?? this.isFetchingContent,
      isFetchingAudio: isFetchingAudio ?? this.isFetchingAudio,
      content: content ?? this.content,
      wordDefinition: wordDefinition ?? this.wordDefinition,
      audioUrl: clearAudioUrl ? null : (audioUrl ?? this.audioUrl),
      contentError: clearContentError
          ? null
          : (contentError ?? this.contentError),
      audioError: clearAudioError ? null : (audioError ?? this.audioError),
      hasAudio: hasAudio ?? this.hasAudio,
    );
  }
}
