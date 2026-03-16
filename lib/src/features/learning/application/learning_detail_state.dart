import 'package:flutter/foundation.dart';

@immutable
class LearningDetailState {
  final bool isLoading;
  final bool isFetchingContent;
  final bool isFetchingAudio;
  final String content;
  final String? audioUrl;
  final String? contentError;
  final String? audioError;
  final bool hasAudio;

  const LearningDetailState({
    this.isLoading = true,
    this.isFetchingContent = false,
    this.isFetchingAudio = false,
    this.content = '',
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
    String? audioUrl,
    bool clearAudioUrl = false,
    String? contentError,
    bool clearContentError = false,
    String? audioError,
    bool clearAudioError = false,
    bool? hasAudio,
  }) {
    return LearningDetailState(
      isLoading: isLoading ?? this.isLoading,
      isFetchingContent: isFetchingContent ?? this.isFetchingContent,
      isFetchingAudio: isFetchingAudio ?? this.isFetchingAudio,
      content: content ?? this.content,
      audioUrl: clearAudioUrl ? null : (audioUrl ?? this.audioUrl),
      contentError: clearContentError
          ? null
          : (contentError ?? this.contentError),
      audioError: clearAudioError ? null : (audioError ?? this.audioError),
      hasAudio: hasAudio ?? this.hasAudio,
    );
  }
}
