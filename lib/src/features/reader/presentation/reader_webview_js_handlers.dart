part of 'reader_webview.dart';

/// 把渲染引擎发来的 JS 事件注册到宿主回调。
void _registerJavaScriptHandlers(
  _ReaderWebViewState state,
  InAppWebViewController controller,
) {
  controller.addJavaScriptHandler(
    handlerName: 'onPageCountReady',
    callback: (args) async {
      if (args.isNotEmpty && args[0] is int) {
        state.widget.callbacks.onPageCountReady(args[0] as int);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onPageChanged',
    callback: (args) {
      if (args.isNotEmpty && args[0] is int) {
        state.widget.callbacks.onPageChanged(args[0] as int);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onScrollAnchors',
    callback: (args) {
      if (args.isEmpty) return;
      final List<String> anchors = List<String>.from(args[0] as List);
      state.widget.callbacks.onScrollAnchors(anchors);
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onTap',
    callback: (args) {
      if (args.isEmpty) return;
      final x = (args[0] as num).toDouble();
      final y = (args[1] as num).toDouble();
      state.widget.callbacks.onTap(x, y);
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onFootnoteTap',
    callback: (args) {
      if (args.isEmpty) return;
      final innerHtml = args[0] as String;
      final rect = Rect.fromLTWH(
        (args[1] as num).toDouble(),
        (args[2] as num).toDouble(),
        (args[3] as num).toDouble(),
        (args[4] as num).toDouble(),
      );
      final baseUrl = args.length > 5 && args[5] is String
          ? args[5] as String
          : '';
      state.widget.callbacks.onFootnoteTap(innerHtml, rect, baseUrl);
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onLinkTap',
    callback: (args) {
      if (args.isEmpty) return;
      final url = args[0] as String;
      final x = (args[1] as num).toDouble();
      final y = (args[2] as num).toDouble();
      if (state.widget.callbacks.shouldHandleLinkTap(url)) {
        state.widget.callbacks.onLinkTap(url);
      } else {
        state.widget.callbacks.onTap(x, y);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onWordTap',
    callback: (args) {
      if (args.length >= 2) {
        final word = args[0] as String;
        final context = args[1] as String;
        state.widget.callbacks.onWordTap(word, context);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onSentenceSelected',
    callback: (args) {
      if (args.isNotEmpty) {
        final sentence = args[0] as String;
        state.widget.callbacks.onSentenceSelected(sentence);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onImageLongPress',
    callback: (args) {
      if (args.length >= 5 && args[0] is String) {
        final imageUrl = args[0] as String;
        final rect = Rect.fromLTWH(
          (args[1] as num).toDouble(),
          (args[2] as num).toDouble(),
          (args[3] as num).toDouble(),
          (args[4] as num).toDouble(),
        );
        state.widget.callbacks.onImageLongPress(imageUrl, rect);
      }
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onViewportResize',
    callback: (args) {
      state._updateTheme(state._currentTheme);
    },
  );

  controller.addJavaScriptHandler(
    handlerName: 'onEventFinished',
    callback: (args) {
      if (args.isNotEmpty) {
        state._bridge.resolveToken(args[0] as int);
      }
    },
  );
}
