import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synlen/src/core/url_launcher/url_launcher.dart';
import 'package:synlen/src/features/reader/application/volume_control_service.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';
import 'package:synlen/src/features/reader/presentation/widgets/footnot_popup_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../application/reader_navigator.dart';
import '../application/reader_settings_notifier.dart';
import '../application/reader_workflow.dart';
import '../domain/reader_settings.dart';
import '../../../core/services/toast_service.dart';
import '../../library/domain/book_manifest.dart';
import '../application/book_session.dart';
import '../../learning/application/learning_entry.dart';
import '../application/reader_session_factory.dart';
import '../application/volume_key_page_turn.dart';
import 'reader_nav_feedback.dart';
import 'reader_toc_state.dart';
import './reader_renderer.dart';
import '../application/book_webview_handler.dart';
import 'reader_webview.dart';
import 'widgets/reader_shell.dart';
import 'widgets/reader_stage.dart';
import './toc_drawer.dart';
import './widgets/reader_image_overlay.dart';
import '../../../../l10n/app_localizations.dart';

part 'mixins/theme_mixin.dart';
part 'mixins/link_handling_mixin.dart';
part 'mixins/image_viewer_mixin.dart';
part 'mixins/footnote_mixin.dart';

/// Reads EPUB directly from compressed file without extraction
class ReaderScreen extends ConsumerStatefulWidget {
  final String fileHash;

  const ReaderScreen({super.key, required this.fileHash});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with
        WidgetsBindingObserver,
        _ThemeMixin,
        _LinkHandlingMixin,
        _ImageViewerMixin,
        _FootnoteMixin {
  @override
  late final BookWebViewHandler webViewHandler;

  @override
  late final BookSession bookSession;

  final ReaderRendererController rendererController =
      ReaderRendererController();

  /// 导航状态机：位置与忙态的唯一拥有者。
  ReaderNavigator get navigator => workflow.navigator;

  @override
  late final ReaderWorkflow workflow;

  // 覆盖层状态：TOC 高亮与页码显示，跟随导航状态由宿主更新。
  final tocState = ReaderTocState();
  final ValueNotifier<String> displayProgressNotifier = ValueNotifier('');

  @override
  bool showControls = false;

  // WebView visibility control for smoother transitions
  Animation<double>? routeAnimation;
  bool shouldShowWebView = false;

  Timer? _progressLabelTimer;
  bool _exitInProgress = false;

  // Theme state (used by _ThemeMixin)
  @override
  ThemeData? currentTheme;

  // Image viewer state (used by _ImageViewerMixin)
  @override
  bool isImageViewerVisible = false;
  @override
  String? currentImageUrl;
  @override
  Rect? currentImageRect;

  // Footnote state (used by _FootnoteMixin)
  @override
  OverlayEntry? footnoteOverlayEntry;
  @override
  final GlobalKey<FootnotePopupOverlayState> footnoteKey =
      GlobalKey<FootnotePopupOverlayState>();
  @override
  bool isClosingFootnote = false;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  /// 音量键翻页：拦截开关与事件分发（application）。
  late final VolumeKeyPageTurnController volumeKeyPageTurn;

  ProviderSubscription<ReaderSettings>? _readerSettingsSubscription;
  ProviderSubscription<bool>? _volumeKeyTurnsPageSubscription;
  bool tocDrawerOpen = false;
  bool styleDrawerOpen = false;
  AppLifecycleState? lastLifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    final sessionFactory = ref.read(readerSessionFactoryProvider.notifier);
    webViewHandler = sessionFactory.createWebViewHandler();
    workflow = sessionFactory.createWorkflow(
      widget.fileHash,
      rendererController,
    );
    bookSession = workflow.book;
    navigator.state.addListener(_refreshNavigationView);
    workflow.failure.addListener(_showFailure);
    volumeKeyPageTurn = VolumeKeyPageTurnController(
      events: VolumeControlService.volumeKeyEvents,
      enableInterception: VolumeControlService.enableInterception,
      disableInterception: VolumeControlService.disableInterception,
      onPreviousPage: () => rendererController.performPreviousPageTurn(),
      onNextPage: () => rendererController.performNextPageTurn(),
      isEnabled: () => ref.read(readerSettingsProvider).volumeKeyTurnsPage,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _loadBook();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ModalRoute.of(context);
      if (router != null && router.animation != null) {
        routeAnimation = router.animation!;
        routeAnimation?.addStatusListener(handleRouteAnimationStatus);
      } else {
        shouldShowWebView = true;
      }
    });
    hideBottomNavigationBar();
    setupVolumeControl();
    WakelockPlus.enable();
    _readerSettingsSubscription = ref.listenManual(readerSettingsProvider, (
      previous,
      next,
    ) {
      if (previous == null || previous == next) {
        return;
      }

      if (previous.fontFileName != next.fontFileName ||
          previous.overrideFontFamily != next.overrideFontFamily) {
        updateWebViewTheme();
      } else if (previous.zoom != next.zoom) {
        updateWebViewThemeWithDebounce();
      } else {
        updateWebViewTheme();
      }
    });
    _volumeKeyTurnsPageSubscription = ref.listenManual(
      readerSettingsProvider.select((s) => s.volumeKeyTurnsPage),
      (previous, next) {
        if (previous != next) {
          setupVolumeControl();
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeAnimation?.removeStatusListener(handleRouteAnimationStatus);
    routeAnimation = null;
    _progressLabelTimer?.cancel();
    navigator.state.removeListener(_refreshNavigationView);
    workflow.failure.removeListener(_showFailure);
    unawaited(workflow.close());
    _readerSettingsSubscription?.close();
    _volumeKeyTurnsPageSubscription?.close();
    tocState.dispose();
    displayProgressNotifier.dispose();
    removeFootnoteOverlay(animate: false);
    restoreSystemUI();
    volumeKeyPageTurn.dispose();
    WakelockPlus.disable();
    webViewHandler.clearCache();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(workflow.flush());
    }

    lastLifecycleState = state;
    setupVolumeControl();
  }

  Future<void> _leaveReader() async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    final saved = await workflow.flush();
    _exitInProgress = false;
    if (!mounted || !saved) return;
    if (ModalRoute.of(context)?.isCurrent == true) context.pop();
  }

  /// 设置项、抽屉开合与前后台状态共同决定是否拦截音量键。
  void setupVolumeControl() {
    volumeKeyPageTurn.sync(
      enabled:
          ref.read(readerSettingsProvider).volumeKeyTurnsPage &&
          !tocDrawerOpen &&
          !styleDrawerOpen &&
          lastLifecycleState == AppLifecycleState.resumed,
    );
  }

  void _refreshNavigationView() {
    if (!mounted) return;
    final nav = navigator.state.value;
    tocState.refresh(bookSession, nav.spineIndex);
    _progressLabelTimer?.cancel();
    _progressLabelTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || navigator.state.value.isBusy) return;
      final current = navigator.state.value;
      displayProgressNotifier.value =
          '${current.pageInChapter + 1}/${current.totalPagesInChapter}';
    });
  }

  void _showFailure() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = switch (workflow.failure.value) {
      ReaderFailure.bookNotFound => l10n.bookNotFound,
      ReaderFailure.load => l10n.readerLoadFailed,
      ReaderFailure.render => l10n.readerRenderFailed,
      ReaderFailure.progress => l10n.readingProgressSaveFailed,
      null => null,
    };
    if (message != null) ToastService.showError(message);
  }

  void handleScrollAnchors(List<String> anchorIds) {
    tocState.updateAnchors(
      bookSession,
      navigator.state.value.spineIndex,
      anchorIds,
    );
  }

  /// 导航结果 → l10n 提示；成功与忽略不出提示。
  void _showNavOutcome(ReaderNavOutcome outcome) {
    if (!mounted) return;
    ReaderNavFeedback(
      l10n: AppLocalizations.of(context)!,
      theme: getEpubTheme().themeData,
    ).show(outcome);
  }

  /// 导航反馈只映射文案，位置与进度由会话同步。
  Future<void> _navigate(Future<ReaderNavOutcome> Function() action) async {
    final outcome = await action();
    if (!mounted) return;
    _showNavOutcome(outcome);
  }

  /// 翻页前的边界判定：越界时提示并阻止本次翻页。
  bool canPerformPageTurn(bool isNext) {
    final outcome = navigator.canTurnPage(isNext);
    if (outcome != ReaderNavOutcome.moved) _showNavOutcome(outcome);
    return outcome == ReaderNavOutcome.moved;
  }

  Future<void> handlePageTurn(bool isNext) =>
      _navigate(() => workflow.turnPage(isNext));

  Future<void> navigateToTocItem(TocItem item) =>
      _navigate(() => workflow.goToTocItem(item));

  Future<void> navigateToFirstTocItemFirstPage() =>
      _navigate(() => workflow.goToChapter(0));

  void hideBottomNavigationBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  void restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    handleSystemThemeChanged();
  }

  void handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        shouldShowWebView = true;
      });
      routeAnimation?.removeStatusListener(handleRouteAnimationStatus);
      routeAnimation = null;
    }
  }

  /// 书目就绪后挂载视口，分页初始化由 WebView 就绪事件触发。
  Future<void> _loadBook() async {
    final loaded = await workflow.open();
    if (!mounted) return;
    if (!loaded) {
      context.pop();
      return;
    }
    _refreshNavigationView();
    setState(() {});
  }

  void toggleControls() {
    if (showControls) {
      hideBottomNavigationBar();
    } else {
      restoreSystemUI();
    }
    setState(() {
      showControls = !showControls;
    });
  }

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  void handleWordTap(String word, String wordContext) {
    ref
        .read(learningEntryProvider.notifier)
        .showWord(word: word, context: wordContext);
  }

  void handleSentenceSelected(String sentence) {
    ref.read(learningEntryProvider.notifier).showSentence(sentence: sentence);
  }

  @override
  Widget build(BuildContext context) {
    // Block rendering until SharedPreferences (and thus ReaderSettings) are ready.
    final settings = ref.watch(readerSettingsProvider);
    if (!bookSession.isLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const SizedBox.shrink(),
      );
    }

    final epubTheme = getEpubTheme();
    final isDark = epubTheme.colorScheme.brightness == Brightness.dark;
    final themeData = epubTheme.themeData;

    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: themeData.colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: themeData.colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    return ReaderShell(
      overlayStyle: overlayStyle,
      canPop: footnoteOverlayEntry == null,
      onPopInvoked: (didPop) {
        if (didPop) {
          unawaited(workflow.flush());
          return;
        }
        if (footnoteOverlayEntry != null) {
          removeFootnoteOverlay();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            key: scaffoldKey,
            backgroundColor: epubTheme.colorScheme.surfaceContainer,
            drawer: ValueListenableBuilder<Set<TocItem>>(
              valueListenable: tocState.activeItems,
              builder: (context, activeItems, child) {
                final book = bookSession.book!;
                return TocDrawer(
                  title: book.title,
                  author: book.author,
                  coverPath: book.coverPath,
                  totalChapters: book.totalChapters,
                  toc: bookSession.toc,
                  activeTocItems: activeItems,
                  onTocItemSelected: navigateToTocItem,
                  onCoverTap: navigateToFirstTocItemFirstPage,
                  themeData: themeData,
                );
              },
            ),
            onDrawerChanged: (isOpened) {
              tocDrawerOpen = isOpened;
              setupVolumeControl();
            },
            body: ReaderStage(
              bookSession: bookSession,
              navigator: navigator,
              rendererController: rendererController,
              webViewHandler: webViewHandler,
              fileHash: widget.fileHash,
              showControls: showControls,
              shouldShowWebView: shouldShowWebView,
              initializeTheme: settings.toEpubTheme(context),
              activeTocTitle: tocState.activeTitle,
              progressLabel: displayProgressNotifier,
              canPerformPageTurn: canPerformPageTurn,
              onPerformPageTurn: handlePageTurn,
              onToggleControls: toggleControls,
              runInteraction: workflow.renderInteraction,
              callbacks: ReaderWebViewCallbacks(
                onInitialized: () =>
                    workflow.initializeRenderer(theme: getEpubTheme()),
                onViewportResize: () =>
                    workflow.requestTheme(getEpubTheme(), force: true),
                onPageCountReady: workflow.reportPageCount,
                onPageChanged: workflow.reportPageIndex,
                onScrollAnchors: handleScrollAnchors,
                onImageLongPress: handleImageLongPress,
                onTap: (x, y) {},
                onFootnoteTap: handleFootnoteTap,
                onLinkTap: handleLinkTap,
                shouldHandleLinkTap: shouldHandleLinkTap,
                onWordTap: handleWordTap,
                onSentenceSelected: handleSentenceSelected,
              ),
              actions: ReaderPanelActions(
                onPreviousPage: rendererController.performPreviousPageTurn,
                onFirstPage: () => _navigate(() => workflow.goToPage(0)),
                onNextPage: rendererController.performNextPageTurn,
                onLastPage: () => _navigate(
                  () => workflow.goToPage(
                    navigator.state.value.totalPagesInChapter - 1,
                  ),
                ),
                onPreviousChapter: () => _navigate(workflow.previousChapter),
                onNextChapter: () => _navigate(workflow.nextChapter),
              ),
              onBack: _leaveReader,
              onOpenDrawer: openDrawer,
              onToggleStyleDrawer: (show) {
                styleDrawerOpen = show;
                setupVolumeControl();
              },
            ),
          ),

          ReaderImageOverlay(
            visible: isImageViewerVisible,
            imageUrl: currentImageUrl,
            sourceRect: currentImageRect,
            webViewHandler: webViewHandler,
            epubPath: bookSession.book!.filePath!,
            fileHash: widget.fileHash,
            epubTheme: getEpubTheme(),
            onClose: closeImageViewer,
          ),
        ],
      ),
    );
  }
}
