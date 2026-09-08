import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/core/widgets/book_cover.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';

import '../application/book_session.dart';
import '../application/epub_webview_handler.dart';
import '../application/reader_scripts.dart';
import 'package:synlen/src/web/api/webview_bridge.dart';
import 'package:synlen/src/web/api/synlen_api.dart';

part 'reader_webview_controller.dart';
part 'reader_webview_js_handlers.dart';

final InAppWebViewSettings defaultSettings = InAppWebViewSettings(
  disableContextMenu: true,
  disableLongPressContextMenuOnLinks: true,
  selectionGranularity: SelectionGranularity.CHARACTER,
  transparentBackground: true,
  allowFileAccessFromFileURLs: true,
  allowUniversalAccessFromFileURLs: true,
  useShouldInterceptRequest: true,
  useOnLoadResource: false,
  useShouldOverrideUrlLoading: true,
  javaScriptEnabled: true,
  disableHorizontalScroll: true,
  disableVerticalScroll: true,
  supportZoom: false,
  useHybridComposition: false,
  resourceCustomSchemes: [EpubWebViewHandler.virtualScheme],
  verticalScrollBarEnabled: false,
  horizontalScrollBarEnabled: false,
  overScrollMode: OverScrollMode.NEVER,
);

/// WebView widget for reading EPUB content
class ReaderWebView extends StatefulWidget {
  final BookSession bookSession;
  final EpubWebViewHandler webViewHandler;
  final String fileHash;
  final ReaderWebViewCallbacks callbacks;
  final EpubTheme initializeTheme;
  final bool isLoading;
  final ReaderWebViewController controller;
  final VoidCallback? onWebViewCreated;
  final bool shouldShowWebView;
  final String? coverRelativePath;
  final int direction;

  const ReaderWebView({
    super.key,
    required this.bookSession,
    required this.webViewHandler,
    required this.fileHash,
    required this.callbacks,
    required this.initializeTheme,
    required this.isLoading,
    required this.controller,
    this.onWebViewCreated,
    required this.shouldShowWebView,
    this.coverRelativePath,
    required this.direction,
  });

  @override
  State<ReaderWebView> createState() => _ReaderWebViewState();
}

class _ReaderWebViewState extends State<ReaderWebView> {
  final GlobalKey _repaintKey = GlobalKey();

  InAppWebViewController? _controller;
  HeadlessInAppWebView? _headlessWebView;
  bool _isHeadlessInitialized = false;

  bool _isSubsequentLoad = false;

  late EpubTheme _currentTheme;

  final WebViewBridge _bridge = WebViewBridge();
  late final SynlenApi _api = SynlenApi(_bridge);

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initializeTheme;
    widget.controller._attachState(this);
  }

  @override
  void dispose() {
    widget.controller._attachState(null);
    _bridge.detach();
    _headlessWebView?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading) {
      setState(() {
        _isSubsequentLoad = true;
      });
    }
  }

  void _initHeadlessWebViewIfNeeded(double width, double height) {
    if (_isHeadlessInitialized) return;

    _headlessWebView = HeadlessInAppWebView(
      initialData: _generateInitialData(width, height),
      initialSettings: defaultSettings,
      shouldInterceptRequest: _shouldInterceptRequest,
      onLoadResourceWithCustomScheme: _onLoadResourceWithCustomScheme,
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      onWebViewCreated: _onWebViewCreated,
      onLoadStop: _onLoadStop,
    );

    _headlessWebView?.run();
    _isHeadlessInitialized = true;
  }

  Future<void> _waitForWebviewRender() async {
    if (_controller == null) return;
    await _api.waitForRender();
  }

  Future<void> _waitForRender() async {
    await _waitForWebviewRender();
  }

  Future<int> _jumpToLastPageOfFrame(String frame) =>
      _api.jumpToLastPageOfFrame(frame);

  Future<int> _cycleFrames(String direction) => _api.cycleFrames(direction);

  Future<int> _jumpToPageFor(String frame, int pageIndex) =>
      _api.jumpToPageFor(frame, pageIndex);

  Future<int> _loadFrame(
    String frame,
    String url,
    String anchors,
    String properties,
  ) => _api.loadFrame(frame, url, anchors, properties);

  Future<void> _jumpToPage(int pageIndex) => _api.jumpToPage(pageIndex);

  Future<void> _restoreScrollPosition(double ratio) =>
      _api.restoreScrollPosition(ratio);

  Future<void> _checkLongPressElementAt(double x, double y) =>
      _api.checkLongPressElementAt(x, y);

  Future<void> _checkTapElementAt(double x, double y) =>
      _api.checkTapElementAt(x, y);

  InAppWebViewInitialData _generateInitialData(double width, double height) {
    return InAppWebViewInitialData(
      data: generateSkeletonHtml(
        width,
        height,
        _currentTheme,
        widget.direction,
      ),
      baseUrl: WebUri(EpubWebViewHandler.getBaseUrl()),
    );
  }

  Future<WebResourceResponse?> _shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    return await widget.webViewHandler.handleRequest(
      epubPath: widget.bookSession.book!.filePath!,
      fileHash: widget.fileHash,
      requestUrl: request.url,
    );
  }

  Future<CustomSchemeResponse?> _onLoadResourceWithCustomScheme(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    return await widget.webViewHandler.handleRequestWithCustomScheme(
      epubPath: widget.bookSession.book!.filePath!,
      fileHash: widget.fileHash,
      requestUrl: request.url,
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url!;
    if (uri.scheme == 'data') {
      return NavigationActionPolicy.ALLOW;
    }
    if (EpubWebViewHandler.isEpubRequest(uri)) {
      return NavigationActionPolicy.ALLOW;
    }
    return NavigationActionPolicy.CANCEL;
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _bridge.attach(controller);
    _registerJavaScriptHandlers(this, controller);
    widget.onWebViewCreated?.call();
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) {
    widget.callbacks.onInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - _currentTheme.padding.horizontal;
        final height = constraints.maxHeight - _currentTheme.padding.vertical;
        _initHeadlessWebViewIfNeeded(width, height);

        return Stack(
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: AbsorbPointer(
                child: widget.shouldShowWebView
                    ? InAppWebView(
                        headlessWebView: _headlessWebView,
                        initialData: _generateInitialData(width, height),
                        initialSettings: defaultSettings,
                        shouldInterceptRequest: _shouldInterceptRequest,
                        onLoadResourceWithCustomScheme:
                            _onLoadResourceWithCustomScheme,
                        shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
                        onWebViewCreated: _onWebViewCreated,
                        onLoadStop: _onLoadStop,
                      )
                    : Container(color: _currentTheme.surfaceColor),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !widget.isLoading && widget.shouldShowWebView,
                child: AnimatedOpacity(
                  duration: (widget.isLoading || !widget.shouldShowWebView)
                      ? Duration.zero
                      : const Duration(
                          milliseconds: AppTheme.defaultAnimationDurationMs,
                        ),
                  curve: Curves.easeOut,
                  opacity: (widget.isLoading || !widget.shouldShowWebView)
                      ? 1.0
                      : 0.0,
                  child: Container(
                    color: _currentTheme.surfaceColor,
                    child: _isSubsequentLoad
                        ? null
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                              ),
                              child: Theme(
                                data: _currentTheme.themeData,
                                child: BookCover(
                                  relativePath: widget.coverRelativePath,
                                  radius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<ui.Image?> _takeScreenshot() async {
    if (Platform.isAndroid) {
      // for Android
      final BuildContext? context = _repaintKey.currentContext;
      if (context == null) return null;

      final RenderRepaintBoundary? boundary =
          context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;
      // 降低像素比以提高截图性能，减少主线程卡顿
      // 3.0 对于全屏 WebView 来说过于沉重
      ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      return image;
    } else {
      throw UnimplementedError(
        'Do not use screenshot on iOS, it may cause performance issues.',
      );
    }
  }

  Future<void> _updateTheme(EpubTheme theme) async {
    if (_controller == null) return;
    final width = MediaQuery.of(context).size.width - theme.padding.horizontal;
    final height = MediaQuery.of(context).size.height - theme.padding.vertical;
    _currentTheme = theme;
    await _api.updateTheme(width, height, theme.toMap());
  }
}
