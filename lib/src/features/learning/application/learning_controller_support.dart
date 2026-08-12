import 'dart:async';

Future<void> consumeLearningContentStream({
  required Stream<String> stream,
  required bool Function() isDisposed,
  required void Function(String appendedContent) onContent,
  Duration throttle = const Duration(milliseconds: 100),
}) async {
  var buffer = '';
  var lastUpdateTime = DateTime.now();

  await for (final chunk in stream) {
    if (isDisposed()) {
      return;
    }

    buffer += chunk;
    final now = DateTime.now();
    if (now.difference(lastUpdateTime) < throttle) {
      continue;
    }

    onContent(buffer);
    buffer = '';
    lastUpdateTime = now;
  }

  if (!isDisposed() && buffer.isNotEmpty) {
    onContent(buffer);
  }
}
