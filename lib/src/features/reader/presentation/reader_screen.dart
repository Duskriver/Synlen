import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumina/src/core/theme/app_theme.dart';
import 'package:lumina/src/features/reader/data/services/volume_control_service.dart';
import 'package:lumina/src/features/reader/domain/epub_theme.dart';
import 'package:lumina/src/features/reader/presentation/widgets/footnot_popup_overlay.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../application/reader_settings_notifier.dart';
import '../domain/reader_settings.dart';
import '../../../core/services/toast_service.dart';
import '../../library/domain/book_manifest.dart';
import './image_viewer.dart';
import '../data/book_session.dart';
import './reader_renderer.dart';
import './control_panel.dart';
import '../data/services/epub_stream_service_provider.dart';
import '../../library/data/repositories/shelf_book_repository_provider.dart';
import '../../library/data/repositories/book_manifest_repository_provider.dart';
import '../data/epub_webview_handler.dart';
import './toc_drawer.dart';
import '../../../../l10n/app_localizations.dart';

import '../../learning/presentation/widgets/word_definition_dialog.dart';
import '../../learning/presentation/widgets/sentence_analysis_dialog.dart';

part 'mixins/spine_navigation_mixin.dart';
part 'mixins/page_navigation_mixin.dart';
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

  // Core UI state
  @override
  bool isWebViewLoading = true;

  @override
  bool showControls = false;

  // WebView visibility control for smoother transitions
  Animation<double>? routeAnimation;
  bool shouldShowWebView = false;

  // Spine navigation state (used by _SpineNavigationMixin)
  @override
  int get currentSpineItemIndex => _currentSpineItemIndex;
  int _currentSpineItemIndex = 0;
  final ValueNotifier<int> _currentSpineItemNotifier = ValueNotifier(0);

  @override
  set currentSpineItemIndex(int value) {
    if (_currentSpineItemIndex == value) return;
    _currentSpineItemIndex = value;
    _currentSpineItemNotifier.value = value;
  }

  // Pagination state (used by _PageNavigationMixin)
  @override
  int get currentPageInChapter => _currentPageInChapter;
  int _currentPageInChapter = 0;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(0);

  @override
  set currentPageInChapter(int value) {
    if (_currentPageInChapter == value) return;
    _currentPageInChapter = value;
    _currentPageNotifier.value = value;
  }

  @override
  int get totalPagesInChapter => _totalPagesInChapter;
  int _totalPagesInChapter = 1;
  final ValueNotifier<int> _totalPagesNotifier = ValueNotifier(1);

  @override
  set totalPagesInChapter(int value) {
    if (_totalPagesInChapter == value) return;
    _totalPagesInChapter = value;
    _totalPagesNotifier.value = value;
  }

  // Progress state (used by _ProgressMixin)
  @override
  String get displayProgress => _displayProgress;
  String _displayProgress = '0.00%';
  final ValueNotifier<String> _displayProgressNotifier = ValueNotifier('0.00%');

  @override
  set displayProgress(String value) {
    if (_displayProgress == value) return;
    _displayProgress = value;
    _displayProgressNotifier.value = value;
  }

  @override
  Timer? progressDebouncer;
  @override
  Timer? _saveProgressDebouncer;

  // Theme state (used by _ThemeMixin)
  @override
  ThemeData? currentTheme;
  @override
  bool updatingTheme = false;
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
  final ValueNotifier<Set<TocItem>> _activeTocItemsNotifier = ValueNotifier(
    <TocItem>{},
  );
  final ValueNotifier<String> _activeTocTitleNotifier = ValueNotifier('');

  @override
  void initState() {
    super.initState();
    webViewHandler = EpubWebViewHandler(
      streamService: ref.read(epubStreamServiceProvider),
    );
    bookSession = BookSession(
      fileHash: widget.fileHash,
      shelfBookRepository: ref.read(shelfBookRepositoryProvider),
      manifestRepository: ref.read(bookManifestRepositoryProvider),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _loadBook();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ModalRoute.of(context);
      currentTheme = Theme.of(context);
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
    _readerSettingsSubscription = ref.listenManual(
      readerSettingsNotifierProvider,
      (previous, next) {
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
      },
    );
    _volumeKeyTurnsPageSubscription = ref.listenManual(
      readerSettingsNotifierProvider.select((s) => s.volumeKeyTurnsPage),
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
    _readerSettingsSubscription?.close();
    _volumeKeyTurnsPageSubscription?.close();
    _currentSpineItemNotifier.dispose();
    _currentPageNotifier.dispose();
    _totalPagesNotifier.dispose();
    _displayProgressNotifier.dispose();
    _activeTocItemsNotifier.dispose();
    _activeTocTitleNotifier.dispose();
    removeFootnoteOverlay(animate: false);
    restoreSystemUI();
    volumeSubscription?.cancel();
    VolumeControlService.disableInterception();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      saveProgress();
    }

    lastLifecycleState = state;
    setupVolumeControl();
  }

  void setupVolumeControl() {
    final resume =
        ref.read(readerSettingsNotifierProvider).volumeKeyTurnsPage &&
        !tocDrawerOpen &&
        !styleDrawerOpen &&
        lastLifecycleState == AppLifecycleState.resumed;

    if (resume) {
      VolumeControlService.enableInterception();
      volumeSubscription ??= VolumeControlService.volumeKeyEvents.listen((
        event,
      ) {
        final isVolumeTurnEnabled = ref
            .read(readerSettingsNotifierProvider)
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
    if (!setEquals(_activeTocItemsNotifier.value, activeItems)) {
      _activeTocItemsNotifier.value = activeItems;
    }

    final title = activeItems.isNotEmpty
        ? activeItems.last.label
        : bookSession.book?.title ?? '';
    if (_activeTocTitleNotifier.value != title) {
      _activeTocTitleNotifier.value = title;
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

    // Update WebView theme when system theme changes
    if (currentTheme != null && currentTheme != Theme.of(context)) {
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
    debugPrint('Word Tapped: $word');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: WordDefinitionDialog(
              word: word,
              context: wordContext,
              scrollController: controller,
            ),
          );
        },
      ),
    );
  }

  void handleSentenceSelected(String sentence) {
    debugPrint('Sentence Selected: $sentence');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SentenceAnalysisDialog(
              sentence: sentence,
              scrollController: controller,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Block rendering until SharedPreferences (and thus ReaderSettings) are ready.
    final settings = ref.watch(readerSettingsNotifierProvider);
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
        if (didPop) return;
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
                valueListenable: _activeTocItemsNotifier,
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
                      statusBarLeftContent: _activeTocTitleNotifier,
                      statusBarRightContent: _displayProgressNotifier,
                    ),

                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _activeTocTitleNotifier,
                        _currentSpineItemNotifier,
                        _currentPageNotifier,
                        _totalPagesNotifier,
                      ]),
                      builder: (context, child) {
                        return ControlPanel(
                          showControls: showControls,
                          title: bookSession.spine.isEmpty
                              ? bookSession.book!.title
                              : _activeTocTitleNotifier.value,
                          currentSpineItemIndex:
                              _currentSpineItemNotifier.value,
                          totalSpineItems: bookSession.spine.length,
                          currentPageInChapter: _currentPageNotifier.value,
                          totalPagesInChapter: _totalPagesNotifier.value,
                          direction: bookSession.book!.direction,
                          onBack: () {
                            saveProgress();
                            context.pop();
                          },
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
