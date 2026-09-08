import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/book_session.dart';
import '../../application/book_webview_handler.dart';
import '../../application/reader_navigator.dart';
import '../../domain/epub_theme.dart';
import '../control_panel.dart';
import '../reader_renderer.dart';
import '../reader_webview.dart';

/// 控制面板的翻页 / 翻章动作；由宿主组装，舞台与面板只调用。
class ReaderPanelActions {
  const ReaderPanelActions({
    required this.onPreviousPage,
    required this.onFirstPage,
    required this.onNextPage,
    required this.onLastPage,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  final VoidCallback onPreviousPage;
  final VoidCallback onFirstPage;
  final VoidCallback onNextPage;
  final VoidCallback onLastPage;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
}

/// 阅读区舞台：三 iframe 渲染器 + 控制面板。
///
/// 只把导航状态与回调装配到两个子组件上；位置与忙态的真相在
/// [ReaderNavigator]，本组件不持有任何状态。
class ReaderStage extends StatelessWidget {
  const ReaderStage({
    super.key,
    required this.bookSession,
    required this.navigator,
    required this.rendererController,
    required this.webViewHandler,
    required this.fileHash,
    required this.showControls,
    required this.shouldShowWebView,
    required this.initializeTheme,
    required this.activeTocTitle,
    required this.progressLabel,
    required this.canPerformPageTurn,
    required this.onPerformPageTurn,
    required this.onToggleControls,
    required this.callbacks,
    required this.actions,
    required this.onBack,
    required this.onOpenDrawer,
    required this.onToggleStyleDrawer,
  });

  final BookSession bookSession;
  final ReaderNavigator navigator;
  final ReaderRendererController rendererController;
  final BookWebViewHandler webViewHandler;
  final String fileHash;
  final bool showControls;
  final bool shouldShowWebView;
  final EpubTheme initializeTheme;
  final ValueListenable<String> activeTocTitle;
  final ValueListenable<String> progressLabel;
  final bool Function(bool isNext) canPerformPageTurn;
  final Future<void> Function(bool isNext) onPerformPageTurn;
  final VoidCallback onToggleControls;
  final ReaderWebViewCallbacks callbacks;
  final ReaderPanelActions actions;
  final VoidCallback onBack;
  final VoidCallback onOpenDrawer;
  final void Function(bool show) onToggleStyleDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: initializeTheme.surfaceColor,
      child: Stack(
        children: [
          ReaderRenderer(
            controller: rendererController,
            bookSession: bookSession,
            webViewHandler: webViewHandler,
            fileHash: fileHash,
            showControls: showControls,
            isLoading:
                navigator.state.value.isLoading ||
                navigator.state.value.isRefreshingTheme,
            canPerformPageTurn: canPerformPageTurn,
            onPerformPageTurn: onPerformPageTurn,
            onToggleControls: onToggleControls,
            callbacks: callbacks,
            shouldShowWebView: shouldShowWebView,
            initializeTheme: initializeTheme,
            statusBarLeftContent: activeTocTitle,
            statusBarRightContent: progressLabel,
          ),
          ListenableBuilder(
            listenable: Listenable.merge([navigator.state, activeTocTitle]),
            builder: (context, child) {
              final nav = navigator.state.value;
              return ControlPanel(
                showControls: showControls,
                title: bookSession.spine.isEmpty
                    ? bookSession.book!.title
                    : activeTocTitle.value,
                currentSpineItemIndex: nav.spineIndex,
                totalSpineItems: bookSession.spine.length,
                currentPageInChapter: nav.pageInChapter,
                totalPagesInChapter: nav.totalPagesInChapter,
                direction: bookSession.book!.direction,
                onBack: onBack,
                onOpenDrawer: onOpenDrawer,
                onPreviousPage: actions.onPreviousPage,
                onFirstPage: actions.onFirstPage,
                onNextPage: actions.onNextPage,
                onLastPage: actions.onLastPage,
                onPreviousChapter: actions.onPreviousChapter,
                onNextChapter: actions.onNextChapter,
                onToggleStyleDrawer: onToggleStyleDrawer,
              );
            },
          ),
        ],
      ),
    );
  }
}
