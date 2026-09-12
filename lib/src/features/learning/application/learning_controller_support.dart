import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/features/learning/application/learning_audio_coordinator.dart';
import 'package:synlen/src/features/learning/application/learning_audio_player.dart';
import 'package:synlen/src/features/learning/domain/learning_cancellation.dart';

part 'learning_controller_support.g.dart';

/// 每个查询创建独立播放器；测试可替换工厂而不触及平台通道。
@riverpod
LearningAudioPlayer Function() learningAudioPlayerFactory(Ref ref) =>
    FlutterSoundLearningAudioPlayer.new;

/// 一次 Controller 构建的资源所有者，旧查询结束后不得再更新状态。
class LearningControllerSession<T> {
  LearningControllerSession({required this.repository, required this.audio});

  final T repository;
  final LearningAudioCoordinator audio;
  final cancellation = LearningCancellation();

  bool get isDisposed => cancellation.isCancelled;

  void dispose() {
    if (isDisposed) return;
    cancellation.cancel();
    audio.dispose();
  }
}

/// 流消费的最小更新间隔，避免高频回调触发整页重建。
const Duration _kThrottle = Duration(milliseconds: 100);

Future<void> consumeLearningContentStream({
  required Stream<String> stream,
  required bool Function() isDisposed,
  required void Function(String appendedContent) onContent,
  required LearningCancellation cancellation,
}) async {
  if (isDisposed()) return;
  final iterator = StreamIterator(stream);
  final unregister = cancellation.onCancel(() => unawaited(iterator.cancel()));
  var buffer = '';
  var lastUpdateTime = DateTime.now();
  try {
    while (await iterator.moveNext()) {
      if (isDisposed()) return;
      buffer += iterator.current;
      final now = DateTime.now();
      if (now.difference(lastUpdateTime) < _kThrottle) continue;
      onContent(buffer);
      buffer = '';
      lastUpdateTime = now;
    }
    if (!isDisposed() && buffer.isNotEmpty) onContent(buffer);
  } finally {
    unregister();
    await iterator.cancel();
  }
}
