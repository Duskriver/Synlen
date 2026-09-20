part of 'reader_webview.dart';

/// 只向宿主转发通过协议校验的事件。
void _registerJavaScriptHandlers(
  _ReaderWebViewState state,
  InAppWebViewController controller,
) {
  Rect rect(WebRect value) =>
      Rect.fromLTWH(value.x, value.y, value.width, value.height);
  for (final name in ReaderWebEvent.handlers) {
    controller.addJavaScriptHandler(
      handlerName: name,
      callback: (args) {
        if (!state.mounted) return;
        final callbacks = state.widget.callbacks;
        switch (ReaderWebEvent.decode(name, args)) {
          case ReaderPageCount(:final count):
            callbacks.onPageCountReady(count);
          case ReaderPageChanged(:final index):
            callbacks.onPageChanged(index);
          case ReaderAnchors(:final anchors):
            callbacks.onScrollAnchors(anchors);
          case ReaderTap(:final x, :final y):
            callbacks.onTap(x, y);
          case ReaderLink(:final url, :final x, :final y):
            if (callbacks.shouldHandleLinkTap(url)) {
              callbacks.onLinkTap(url);
            } else {
              callbacks.onTap(x, y);
            }
          case ReaderWord(
            :final word,
            :final context,
            rect: final bounds,
            :final requestId,
          ):
            if (!state._api.acceptWordRequest(requestId)) break;
            final box = state.context.findRenderObject();
            if (box is RenderBox &&
                box.hasSize &&
                state.widget.shouldShowWebView &&
                !state.widget.isLoading) {
              callbacks.onWordTap(
                word,
                context,
                MatrixUtils.transformRect(
                  box.getTransformTo(null),
                  rect(bounds),
                ),
              );
            }
          case ReaderSentence(:final sentence):
            callbacks.onSentenceSelected(sentence);
          case ReaderImage(:final url, rect: final bounds):
            callbacks.onImageLongPress(url, rect(bounds));
          case ReaderFootnote(:final html, rect: final bounds, :final baseUrl):
            callbacks.onFootnoteTap(html, rect(bounds), baseUrl);
          case ReaderResize():
            state._api.invalidateWordRequest();
            callbacks.onViewportResize?.call();
          case ReaderEventFinished(:final token):
            state._bridge.resolveToken(token);
          case null:
            break;
        }
      },
    );
  }
}
