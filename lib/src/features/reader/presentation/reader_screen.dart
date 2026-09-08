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
import '../application/reading_progress_controller.dart';
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
import 'widgets/reader_stage.dart';
import './toc_drawer.dart';
import './widgets/reader_image_overlay.dart';
import '../../../../l10n/app_localizations.dart';

part 'mixins/progress_mixin.dart';
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
        _ProgressMixin,
        _ThemeMixin,
        _LinkHandlingMixin,
        _ImageViewerMixin,
        _FootnoteMixin {
  @override
  late final BookWebViewHandler webViewHandler;

  @override
  late final BookSession bookSession;

  @override
  final ReaderRendererController rendererController =
      ReaderRendererController();

  /// 导航状态机：位置与忙态的唯一拥有者。
  @override
  late final ReaderNavigator navigator;

  // 覆盖层状态：TOC 高亮与页码显示，跟随导航状态由宿主更新。
  final tocState = ReaderTocState();
  final ValueNotifier<String> displayProgressNotifier = ValueNotifier('');

  // 供剩余 mixin 读取的导航状态视图（唯一来源是 navigator.state）。
  @override
  bool get isWebViewLoading => navigator.state.value.isLoading;
  @override
  int get currentSpineItemIndex => navigator.state.value.spineIndex;
  @override
  int get currentPageInChapter => navigator.state.value.pageInChapter;
  @override
  int get totalPagesInChapter => navigator.state.value.totalPagesInChapter;
  @override
  bool get updatingTheme => navigator.state.value.isRefreshingTheme;
  @override
  bool get isChangingChapter => navigator.state.value.isChangingChapter;
  @override
  String get displayProgress => displayProgressNotifier.value;
  @override
  set displayProgress(String value) => displayProgressNotifier.value = value;

  @override
  bool showControls = false;

  // WebView visibility control for smoother transitions
  Animation<double>? routeAnimation;
  bool shouldShowWebView = false;

  @override
  Timer? progressDebouncer;
  @override
  late final ReadingProgressController progressController;
  bool _exitInProgress = false;
  String? _progressSaveFailedMessage;

  // Theme state (used by _ThemeMixin)
  @override
  ThemeData? currentTheme;
  @override
  Timer? themeUpdateDebouncer;

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
    bookSession = sessionFactory.createSession(widget.fileHash);
    navigator = ReaderNavigator(
      session: bookSession,
      viewport: rendererController,
    );
    progressController = ReadingProgressController(
      save: bookSession.saveProgress,
      onSaveFailed: () {
        final message = _progressSaveFailedMessage;
        if (message != null) ToastService.showError(message);
      },
    );
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
    themeUpdateDebouncer?.cancel();
    progressDebouncer?.cancel();
    saveProgressDebounced();
    unawaited(progressController.close());
    _readerSettingsSubscription?.close();
    _volumeKeyTurnsPageSubscription?.close();
    navigator.dispose();
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
      unawaited(saveProgress());
    }

    lastLifecycleState = state;
    setupVolumeControl();
  }

  Future<void> _leaveReader() async {
    if (_exitInProgress) return;
    _exitInProgress = true;
    final saved = await saveProgress();
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

  @override
  void refreshActiveTocState() {
    tocState.refresh(bookSession, navigator.state.value.spineIndex);
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

  /// 执行一次导航动作：提示结果，位置变化后刷新 TOC 与进度。
  Future<void> _navigate(Future<ReaderNavOutcome> Function() action) async {
    final outcome = await action();
    if (!mounted) return;
    _showNavOutcome(outcome);
    if (outcome == ReaderNavOutcome.moved) {
      refreshActiveTocState();
      updateProgressDebounced();
      saveProgressDebounced();
    }
  }

  /// 翻页前的边界判定：越界时提示并阻止本次翻页。
  bool canPerformPageTurn(bool isNext) {
    final outcome = navigator.canTurnPage(isNext);
    if (outcome != ReaderNavOutcome.moved) _showNavOutcome(outcome);
    return outcome == ReaderNavOutcome.moved;
  }

  Future<void> handlePageTurn(bool isNext) =>
      _navigate(() => navigator.turnPage(isNext));

  Future<void> navigateToTocItem(TocItem item) =>
      _navigate(() => navigator.goToTocItem(item));

  Future<void> navigateToFirstTocItemFirstPage() =>
      _navigate(() => navigator.goToChapter(0));

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
    _progressSaveFailedMessage = AppLocalizations.of(
      context,
    )!.readingProgressSaveFailed;

    // Update WebView theme when system theme changes
    if (currentTheme == null) {
      currentTheme = Theme.of(context);
    } else if (currentTheme?.colorScheme != Theme.of(context).colorScheme) {
      currentTheme = Theme.of(context);
      updateWebViewThemeWithDebounce();
    }
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

  /// Load ShelfBook + BookManifest from database
  Future<void> _loadBook() async {
    try {
      final loaded = await bookSession.loadBook();

      if (!loaded) {
        if (mounted) {
          ToastService.showError(AppLocalizations.of(context)!.bookNotFound);
          context.pop();
        }
        return;
      }

      await navigator.load(
        anchor: 'top',
        overrideSpineIndex: bookSession.initialChapterIndex,
      );
      refreshActiveTocState();
      if (mounted) {
        setState(() {});
      }
      updateProgressDebounced();
    } catch (e) {
      if (mounted) {
        ToastService.showError(
          AppLocalizations.of(context)!.errorLoadingBook(e.toString()),
        );
        context.pop();
      }
    }
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

    return PopScope(
      canPop: footnoteOverlayEntry == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(saveProgress());
          return;
        }
        if (footnoteOverlayEntry != null) {
          removeFootnoteOverlay();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Stack(
          children: [
            Scaffold(
              key: scaffoldKey,
              backgroundColor: epubTheme.colorScheme.surfaceContainer,
              drawer: ValueListenableBuilder<Set<TocItem>>(
                valueListenable: tocState.activeItems,
                builder: (context, activeItems, child) {
                  return TocDrawer(
                    book: bookSession.book!,
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
                callbacks: ReaderWebViewCallbacks(
                  onInitialized: () async {
                    final ratio = bookSession.initialScrollPosition;
                    await navigator.load(restoreScrollRatio: ratio);
                    if (!mounted) return;
                    updateProgressDebounced();
                    saveProgressDebounced();
                  },
                  onPageCountReady: (totalPages) async {
                    navigator.reportPageCount(totalPages);
                    updateProgressDebounced();
                  },
                  onPageChanged: (pageIndex) {
                    navigator.reportPageIndex(pageIndex);
                    updateProgressDebounced();
                    saveProgressDebounced();
                  },
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
                  onFirstPage: () => _navigate(() => navigator.goToPage(0)),
                  onNextPage: rendererController.performNextPageTurn,
                  onLastPage: () => _navigate(
                    () => navigator.goToPage(
                      navigator.state.value.totalPagesInChapter - 1,
                    ),
                  ),
                  onPreviousChapter: () =>
                      _navigate(navigator.previousChapterFirstPage),
                  onNextChapter: () => _navigate(navigator.nextChapter),
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
      ),
    );
  }
}
