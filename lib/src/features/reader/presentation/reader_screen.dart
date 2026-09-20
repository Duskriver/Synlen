import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_readium/flutter_readium.dart' hide Href;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/services/toast_service.dart';
import '../../learning/application/learning_entry.dart';
import '../../library/domain/book_manifest.dart';
import '../application/readium_layout.dart';
import '../application/readium_session.dart';
import '../application/reader_session_factory.dart';
import '../application/reader_settings_notifier.dart';
import '../application/volume_control_service.dart';
import '../application/volume_key_page_turn.dart';
import '../domain/reader_settings.dart';
import '../domain/readium_interaction.dart';
import 'control_panel.dart';
import 'reader_page_stage.dart';
import 'readium_image_dialog.dart';
import 'readium_viewport.dart';
import 'toc_drawer.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.fileHash});
  final String fileHash;
  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  late final ReadiumSession session;
  late final VolumeKeyPageTurnController _volume;
  final _scaffold = GlobalKey<ScaffoldState>();
  final _controls = ValueNotifier(false);
  bool _started = false;
  bool _leaving = false;
  bool _canPop = false;
  bool _drawerOpen = false;
  bool _overlayOpen = false;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  ReaderFailure? _lastFailure;
  Publication? _tocPublication;
  List<TocItem> _cachedToc = [];
  ProviderSubscription<ReaderSettings>? _settingsSubscription;

  @override
  void initState() {
    super.initState();
    session = ref.read(readerSessionFactoryProvider).create(widget.fileHash);
    session.addListener(_onSessionChanged);
    _controls.addListener(_onControlsChanged);
    _volume = VolumeKeyPageTurnController(
      events: VolumeControlService.volumeKeyEvents,
      enableInterception: VolumeControlService.enableInterception,
      disableInterception: VolumeControlService.disableInterception,
      onPreviousPage: () => _turn(false),
      onNextPage: () => _turn(true),
      isEnabled: () => ref.read(readerSettingsProvider).volumeKeyTurnsPage,
    );
    WidgetsBinding.instance.addObserver(this);
    _settingsSubscription = ref.listenManual(readerSettingsProvider, (
      previous,
      next,
    ) {
      if (mounted && _started) {
        session.requestLayout(
          ReadiumLayout(
            next.toEpubTheme(context),
            handleInternalLinks: next.handleIntraLink,
          ),
        );
      }
      _syncVolume();
    });
    _syncVolume();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final layout = ReadiumLayout(
      ref.read(readerSettingsProvider).toEpubTheme(context),
      handleInternalLinks: ref.read(readerSettingsProvider).handleIntraLink,
    );
    if (!_started) {
      _started = true;
      unawaited(session.open(layout));
    } else {
      session.requestLayout(layout);
    }
  }

  void _syncVolume() => _volume.sync(
    enabled:
        ref.read(readerSettingsProvider).volumeKeyTurnsPage &&
        !_drawerOpen &&
        !_overlayOpen &&
        session.ready &&
        _lifecycle == AppLifecycleState.resumed,
  );

  void _onSessionChanged() {
    if (!mounted) return;
    _syncVolume();
    final failure = session.failure;
    if (failure != null && failure != _lastFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ToastService.showError(_failureMessage(failure));
      });
    }
    _lastFailure = failure;
    setState(() {});
  }

  String _failureMessage(ReaderFailure failure) {
    final strings = AppLocalizations.of(context)!;
    return switch (failure) {
      ReaderFailure.load => strings.readerLoadFailed,
      ReaderFailure.progress => strings.readingProgressSaveFailed,
      ReaderFailure.link => strings.readerLinkFailed,
      ReaderFailure.image => strings.readerImageFailed,
      ReaderFailure.render => strings.readerRenderFailed,
    };
  }

  void _onControlsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state != AppLifecycleState.resumed) unawaited(session.flush());
    _syncVolume();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final saved = await session.flush();
    _leaving = false;
    if (!mounted || !saved) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  void _turn(bool forward) => unawaited(
    session.turnPage(
      forward,
      animated:
          ref.read(readerSettingsProvider).pageAnimation ==
          ReaderPageAnimation.slide,
    ),
  );

  Future<void> _interaction(String payload) async {
    if (_overlayOpen || _drawerOpen) return;
    final event = session.interaction(session.sessionId, payload);
    if (event == null) return;
    switch (event.kind) {
      case 'controls':
        _toggleControls();
      case 'word':
        _overlayOpen = true;
        _syncVolume();
        _controls.value = false;
        await ref
            .read(learningEntryProvider.notifier)
            .showWord(word: event.word!, context: event.sentence!);
      case 'sentence':
        _overlayOpen = true;
        _syncVolume();
        _controls.value = false;
        await ref
            .read(learningEntryProvider.notifier)
            .showSentence(sentence: event.sentence!);
    }
    if (event.kind != 'controls') {
      _overlayOpen = false;
      if (mounted) _syncVolume();
    }
  }

  void _toggleControls() {
    if (session.ready && !_overlayOpen && !_drawerOpen) {
      _controls.value = !_controls.value;
    }
  }

  Future<void> _externalLink(String url) async {
    final handling = ref.read(readerSettingsProvider).linkHandling;
    if (handling == ReaderLinkHandling.never || _overlayOpen) return;
    _overlayOpen = true;
    _syncVolume();
    var confirmed = handling == ReaderLinkHandling.always;
    if (!confirmed) {
      final strings = AppLocalizations.of(context)!;
      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(strings.openExternalLink),
              content: Text(strings.openExternalLinkConfirmation(url)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(strings.open),
                ),
              ],
            ),
          ) ??
          false;
    }
    if (confirmed && mounted) await session.openExternalLink(url);
    _overlayOpen = false;
    if (mounted) _syncVolume();
  }

  Future<void> _image(ImageTapEvent event) async {
    if (_overlayOpen || !session.ready) return;
    _overlayOpen = true;
    _syncVolume();
    final url = await session.imageResource(event.href);
    if (mounted && url != null) {
      await showDialog<void>(
        context: context,
        builder: (_) => ReadiumImageDialog(
          url: url,
          svg: Uri.parse(event.href).path.toLowerCase().endsWith('.svg'),
        ),
      );
    }
    _overlayOpen = false;
    if (mounted) _syncVolume();
  }

  List<TocItem> _toc() {
    if (identical(_tocPublication, session.publication)) return _cachedToc;
    _tocPublication = session.publication;
    TocItem map(Link link) => TocItem(
      label: link.title ?? link.href,
      href: Href(
        path: Uri.parse(link.href).path,
        anchor: Uri.parse(link.href).fragment,
      ),
      children: link.children.map(map).toList(),
    );
    return _cachedToc = (session.publication?.tableOfContents ?? const <Link>[])
        .map(map)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(readerSettingsProvider);
    final theme = settings.toEpubTheme(context).themeData;
    final book = session.prepared?.book;
    final toc = _toc();
    final currentHref = session.locator?.href ?? '';
    final active = <TocItem>{};
    void collect(List<TocItem> items) {
      for (final item in items) {
        if (resourcePath(item.href.toString()) == resourcePath(currentHref)) {
          active.add(item);
        }
        collect(item.children);
      }
    }

    collect(toc);
    final title =
        session.locator?.title ??
        active.firstOrNull?.label ??
        book?.title ??
        '';
    final strings = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Theme(
        data: theme,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          child: Scaffold(
            key: _scaffold,
            resizeToAvoidBottomInset: false,
            backgroundColor: theme.colorScheme.surface,
            drawer: book == null
                ? null
                : TocDrawer(
                    title: book.title,
                    author: book.author,
                    coverPath: book.coverPath,
                    totalChapters: session.readingOrder.length,
                    toc: toc,
                    activeTocItems: active,
                    onTocItemSelected: (item) =>
                        unawaited(session.goTo(item.href.toString())),
                    onCoverTap: () => unawaited(session.goToChapter(0)),
                    themeData: theme,
                  ),
            onDrawerChanged: (open) {
              _drawerOpen = open;
              _syncVolume();
            },
            body: Stack(
              children: [
                if (session.publication != null)
                  SafeArea(
                    child: ReaderPageStage(
                      onBlankTap: _toggleControls,
                      padding:
                          (session.layout?.theme.padding ?? EdgeInsets.zero) +
                          const EdgeInsets.only(bottom: 24),
                      child: ReadiumViewport(
                        key: ValueKey(session.sessionId),
                        session: session,
                        controls: _controls,
                        handleInternalLinks:
                            session.layout!.handleInternalLinks,
                        onInteraction: _interaction,
                        onExternalLink: _externalLink,
                        onImage: _image,
                      ),
                    ),
                  ),
                if (session.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (!session.ready && session.failure != null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_failureMessage(session.failure!)),
                        TextButton(
                          onPressed: () => session.open(
                            ReadiumLayout(
                              settings.toEpubTheme(context),
                              handleInternalLinks: settings.handleIntraLink,
                            ),
                          ),
                          child: Text(strings.retry),
                        ),
                      ],
                    ),
                  ),
                if (session.ready && !_controls.value)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.paddingOf(context).bottom + 8,
                    child: IgnorePointer(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          Text(
                            '${(session.fraction * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ControlPanel(
                  showControls: _controls.value || !session.ready,
                  title: title,
                  chapterIndex: session.chapterIndex,
                  chapterCount: session.readingOrder.length,
                  progress: session.fraction,
                  ready: session.ready,
                  rtl:
                      session.publication?.metadata.readingProgression ==
                      ReadingProgression.rtl,
                  onBack: _leave,
                  onOpenDrawer: () => _scaffold.currentState?.openDrawer(),
                  onPreviousPage: () => _turn(false),
                  onNextPage: () => _turn(true),
                  onPreviousChapter: () =>
                      unawaited(session.goToChapter(session.chapterIndex - 1)),
                  onNextChapter: () =>
                      unawaited(session.goToChapter(session.chapterIndex + 1)),
                  onToggleStyleDrawer: (open) {
                    _overlayOpen = open;
                    _syncVolume();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsSubscription?.close();
    _volume.dispose();
    _controls.removeListener(_onControlsChanged);
    _controls.dispose();
    session.removeListener(_onSessionChanged);
    session.dispose();
    super.dispose();
  }
}
