import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/core/url_launcher/url_launcher.dart';
import 'package:synlen/src/features/reader/application/volume_control_service.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';
import 'package:synlen/src/features/reader/presentation/widgets/footnot_popup_overlay.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../application/reader_settings_notifier.dart';
import '../application/reading_progress_controller.dart';
import '../domain/reader_settings.dart';
import '../../../core/services/toast_service.dart';
import '../../library/domain/book_manifest.dart';
import './image_viewer.dart';
import '../application/book_session.dart';
import '../../learning/application/learning_entry.dart';
import '../application/chapter_navigation.dart';
import '../application/page_navigation.dart';
import '../application/reader_session_factory.dart';
import './reader_renderer.dart';
import './control_panel.dart';
import '../application/epub_webview_handler.dart';
import './toc_drawer.dart';
import '../../../../l10n/app_localizations.dart';

part 'mixins/spine_navigation_mixin.dart';
part 'mixins/page_navigation_mixin.dart';
part 'mixins/progress_mixin.dart';
part 'mixins/theme_mixin.dart';
part 'mixins/link_handling_mixin.dart';
part 'mixins/image_viewer_mixin.dart';
part 'mixins/footnote_mixin.dart';

class ReaderViewState {
  bool isWebViewLoading = true;
  bool updatingTheme = false;

  int _currentSpineItemIndex = 0;
  final ValueNotifier<int> currentSpineItemNotifier = ValueNotifier(0);

  int get currentSpineItemIndex => _currentSpineItemIndex;
  set currentSpineItemIndex(int value) {
    if (_currentSpineItemIndex == value) {
      return;
    }
    _currentSpineItemIndex = value;
    currentSpineItemNotifier.value = value;
  }

  int _currentPageInChapter = 0;
  final ValueNotifier<int> currentPageNotifier = ValueNotifier(0);

  int get currentPageInChapter => _currentPageInChapter;
  set currentPageInChapter(int value) {
    if (_currentPageInChapter == value) {
      return;
    }
    _currentPageInChapter = value;
    currentPageNotifier.value = value;
  }

  int _totalPagesInChapter = 0;
  final ValueNotifier<int> totalPagesNotifier = ValueNotifier(0);

  int get totalPagesInChapter => _totalPagesInChapter;
  set totalPagesInChapter(int value) {
    if (_totalPagesInChapter == value) {
      return;
    }
    _totalPagesInChapter = value;
    totalPagesNotifier.value = value;
  }

  String _displayProgress = '';
  final ValueNotifier<String> displayProgressNotifier = ValueNotifier('');

  String get displayProgress => _displayProgress;
  set displayProgress(String value) {
    if (_displayProgress == value) {
      return;
    }
    _displayProgress = value;
    displayProgressNotifier.value = value;
  }

  final ValueNotifier<Set<TocItem>> activeTocItemsNotifier = ValueNotifier(
    <TocItem>{},
  );
  final ValueNotifier<String> activeTocTitleNotifier = ValueNotifier('');

  void dispose() {
    currentSpineItemNotifier.dispose();
    currentPageNotifier.dispose();
    totalPagesNotifier.dispose();
    displayProgressNotifier.dispose();
    activeTocItemsNotifier.dispose();
    activeTocTitleNotifier.dispose();
  }
}

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
        _SpineNavigationMixin,
        _PageNavigationMixin,
        _ProgressMixin,
        _ThemeMixin,
        _LinkHandlingMixin,
        _ImageViewerMixin,
        _FootnoteMixin {
  @override
  late final EpubWebViewHandler webViewHandler;

  @override
  late final BookSession bookSession;

  @override
  final ReaderRendererController rendererController =
      ReaderRendererController();
  final ReaderViewState viewState = ReaderViewState();

  // Core UI state
  @override
  bool get isWebViewLoading => viewState.isWebViewLoading;
  @override
  set isWebViewLoading(bool value) => viewState.isWebViewLoading = value;

  @override
  bool showControls = false;

  // WebView visibility control for smoother transitions
  Animation<double>? routeAnimation;
  bool shouldShowWebView = false;

  // Spine navigation state (used by _SpineNavigationMixin)
  @override
  int get currentSpineItemIndex => viewState.currentSpineItemIndex;
  @override
  set currentSpineItemIndex(int value) =>
      viewState.currentSpineItemIndex = value;

  // Pagination state (used by _PageNavigationMixin)
  @override
  int get currentPageInChapter => viewState.currentPageInChapter;
  @override
  set currentPageInChapter(int value) => viewState.currentPageInChapter = value;

  @override
  int get totalPagesInChapter => viewState.totalPagesInChapter;
  @override
  set totalPagesInChapter(int value) => viewState.totalPagesInChapter = value;

  // Progress state (used by _ProgressMixin)
  @override
  String get displayProgress => viewState.displayProgress;
  @override
  set displayProgress(String value) => viewState.displayProgress = value;

  @override
  Timer? progressDebouncer;
  @override
  late final ReadingProgressController progressController;
  @override
  bool isChangingChapter = false;
  bool _exitInProgress = false;
  String? _progressSaveFailedMessage;

  // Theme state (used by _ThemeMixin)
  @override
  ThemeData? currentTheme;
  @override
  bool get updatingTheme => viewState.updatingTheme;
  @override
  set updatingTheme(bool value) => viewState.updatingTheme = value;
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

  StreamSubscription<String>? volumeSubscription;
  ProviderSubscription<ReaderSettings>? _readerSettingsSubscription;
  ProviderSubscription<bool>? _volumeKeyTurnsPageSubscription;
  bool tocDrawerOpen = false;
  bool styleDrawerOpen = false;
  AppLifecycleState? lastLifecycleState = AppLifecycleState.resumed;

  /// 加载中 / 主题刷新中 / 正在翻章时忽略新的导航请求。
  @override
  bool get isNavigationBusy => shouldIgnoreChapterNavigation(
    isWebViewLoading: isWebViewLoading,
    updatingTheme: updatingTheme,
    isChangingChapter: isChangingChapter,
  );

  @override
  void initState() {
    super.initState();
    final sessionFactory = ref.read(readerSessionFactoryProvider.notifier);
    webViewHandler = sessionFactory.createWebViewHandler();
    bookSession = sessionFactory.createSession(widget.fileHash);
    progressController = ReadingProgressController(
      save: bookSession.saveProgress,
      onSaveFailed: () {
        final message = _progressSaveFailedMessage;
        if (message != null) ToastService.showError(message);
      },
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
    viewState.dispose();
    removeFootnoteOverlay(animate: false);
    restoreSystemUI();
    volumeSubscription?.cancel();
    VolumeControlService.disableInterception();
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

  void setupVolumeControl() {
    final resume =
        ref.read(readerSettingsProvider).volumeKeyTurnsPage &&
        !tocDrawerOpen &&
        !styleDrawerOpen &&
        lastLifecycleState == AppLifecycleState.resumed;

    if (resume) {
      VolumeControlService.enableInterception();
      volumeSubscription ??= VolumeControlService.volumeKeyEvents.listen((
        event,
      ) {
        final isVolumeTurnEnabled = ref
            .read(readerSettingsProvider)
            .volumeKeyTurnsPage;
        if (isVolumeTurnEnabled) {
          if (event == 'up') {
            rendererController.performPreviousPageTurn();
          } else if (event == 'down') {
            rendererController.performNextPageTurn();
          }
        }
      });
    } else {
      VolumeControlService.disableInterception();
    }
  }

  @override
  void refreshActiveTocState() {
    final activeItems = resolveActiveItems();
    if (!setEquals(viewState.activeTocItemsNotifier.value, activeItems)) {
      viewState.activeTocItemsNotifier.value = activeItems;
    }

    final title = activeItems.isNotEmpty
        ? activeItems.last.label
        : bookSession.book?.title ?? '';
    if (viewState.activeTocTitleNotifier.value != title) {
      viewState.activeTocTitleNotifier.value = title;
    }
  }

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

      currentSpineItemIndex = bookSession.initialChapterIndex;
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
                valueListenable: viewState.activeTocItemsNotifier,
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
              body: Container(
                color: epubTheme.surfaceColor,
                child: Stack(
                  children: [
                    ReaderRenderer(
                      controller: rendererController,
                      bookSession: bookSession,
                      webViewHandler: webViewHandler,
                      fileHash: widget.fileHash,
                      showControls: showControls,
                      isLoading: isWebViewLoading || updatingTheme,
                      canPerformPageTurn: canPerformPageTurn,
                      onPerformPageTurn: handlePageTurn,
                      onToggleControls: toggleControls,
                      onInitialized: () async {
                        final ratio = bookSession.initialScrollPosition;
                        await loadCarousel(restoreScrollRatio: ratio);
                      },
                      onPageCountReady: (totalPages) async {
                        totalPagesInChapter = totalPages;
                        if (currentPageInChapter >= totalPagesInChapter) {
                          currentPageInChapter = totalPagesInChapter > 0
                              ? totalPagesInChapter - 1
                              : 0;
                        }
                        updateProgressDebounced();
                      },
                      onPageChanged: (pageIndex) {
                        currentPageInChapter = pageIndex;
                        updateProgressDebounced();
                        saveProgressDebounced();
                      },
                      onScrollAnchors: handleScrollAnchors,
                      onImageLongPress: handleImageLongPress,
                      onFootnoteTap: handleFootnoteTap,
                      onLinkTap: handleLinkTap,
                      shouldHandleLinkTap: shouldHandleLinkTap,
                      onWordTap: handleWordTap,
                      onSentenceSelected: handleSentenceSelected,
                      shouldShowWebView: shouldShowWebView,
                      initializeTheme: settings.toEpubTheme(context),
                      statusBarLeftContent: viewState.activeTocTitleNotifier,
                      statusBarRightContent: viewState.displayProgressNotifier,
                    ),

                    ListenableBuilder(
                      listenable: Listenable.merge([
                        viewState.activeTocTitleNotifier,
                        viewState.currentSpineItemNotifier,
                        viewState.currentPageNotifier,
                        viewState.totalPagesNotifier,
                      ]),
                      builder: (context, child) {
                        return ControlPanel(
                          showControls: showControls,
                          title: bookSession.spine.isEmpty
                              ? bookSession.book!.title
                              : viewState.activeTocTitleNotifier.value,
                          currentSpineItemIndex:
                              viewState.currentSpineItemNotifier.value,
                          totalSpineItems: bookSession.spine.length,
                          currentPageInChapter:
                              viewState.currentPageNotifier.value,
                          totalPagesInChapter:
                              viewState.totalPagesNotifier.value,
                          direction: bookSession.book!.direction,
                          onBack: _leaveReader,
                          onOpenDrawer: openDrawer,
                          onPreviousPage: () =>
                              rendererController.performPreviousPageTurn(),
                          onFirstPage: () => goToPage(0),
                          onNextPage: () =>
                              rendererController.performNextPageTurn(),
                          onLastPage: () => goToPage(totalPagesInChapter - 1),
                          onPreviousChapter: previousSpineItemFirstPage,
                          onNextChapter: nextSpineItem,
                          onToggleStyleDrawer: (show) {
                            styleDrawerOpen = show;
                            setupVolumeControl();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isImageViewerVisible,
                child: AnimatedOpacity(
                  duration: const Duration(
                    milliseconds: AppTheme.defaultAnimationDurationMs,
                  ),
                  curve: Curves.easeOut,
                  opacity: isImageViewerVisible ? 1.0 : 0.0,
                  child: (currentImageUrl != null && currentImageRect != null)
                      ? ImageViewer(
                          imageUrl: currentImageUrl!,
                          webViewHandler: webViewHandler,
                          epubPath: bookSession.book!.filePath!,
                          fileHash: widget.fileHash,
                          onClose: closeImageViewer,
                          sourceRect: currentImageRect!,
                          epubTheme: getEpubTheme(),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
