import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' as mq show Orientation;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'flutter_readium.dart';
import 'reader_channel.dart';
import 'reader_orientation_alignment.dart';
import 'reader_platform_view.dart';

const _viewType = 'dk.nota.flutter_readium/ReadiumReaderWidget';

/// A ReadiumReaderWidget wraps a native Kotlin/Swift Readium navigator widget.
class ReadiumReaderWidget extends StatefulWidget {
  const ReadiumReaderWidget({
    required this.publication,
    this.loadingWidget,
    this.initialLocator,
    this.shouldShowControls,
    this.onExternalLinkActivated,
    this.onTextSelected,
    this.onTextInteraction,
    this.onLocatorChanged,
    this.onReaderReady,
    this.onReaderError,
    this.onReaderDisposed,
    this.sessionId,
    this.handlePointerControls = true,
    this.handleInternalLinks = true,
    this.onSelectionAction,
    this.onDecorationInteraction,
    this.onImageTapped,
    this.selectionActions = const [],
    this.fontFamilyDeclarations = const [],
    this.allowedDefaultActions,
    this.goBackwardSemanticLabel = 'Go Backward',
    this.goForwardSemanticLabel = 'Go Forward',
    this.toggleShowControlsSemanticLabel = 'Toggle show controls',
    this.preloadPreviousPositionCount = 2,
    this.preloadNextPositionCount = 6,
    super.key,
  });

  /// The publication to display, obtained from [FlutterReadium.openPublication].
  final Publication publication;

  /// Optional widget to show while the reader is loading, e.g. a spinner.
  /// It will be shown until the native reader reports that its initial content
  /// is visually ready.
  /// It should typically be a full-screen widget, since it will be stacked on top of the reader widget.
  final Widget? loadingWidget;

  /// Optional locator to restore a previously saved reading position. `null` starts from the beginning.
  final Locator? initialLocator;

  /// Notifier that tells client whether it should show controls, based on user-interaction with the native viewer.
  final ValueNotifier<bool>? shouldShowControls;

  /// Callback invoked when the reader activates an external (non-publication) link.
  final Function(String)? onExternalLinkActivated;

  /// Callback invoked when the user selects text in the reader.
  final ValueChanged<TextSelectionEvent>? onTextSelected;

  /// 原生视口绑定的文字事件；身份字段由原生覆盖，宿主校验内容协议。
  final ValueChanged<String>? onTextInteraction;

  /// 当前视口的位置回执，不共享其他阅读会话的事件流。
  final ValueChanged<Locator>? onLocatorChanged;

  /// 首次位置回执之后调用；不表示后续字号重排已经完成。
  final VoidCallback? onReaderReady;
  final ValueChanged<String>? onReaderError;

  /// 原生视口拆除完成后调用，允许宿主随后重新打开同一出版物。
  final VoidCallback? onReaderDisposed;
  final String? sessionId;

  /// 自定义学习手势接管正文点击时设为 false；保留无障碍语义操作。
  final bool handlePointerControls;

  /// 是否跟随普通书内链接；脚注链接仍由阅读器处理。
  final bool handleInternalLinks;

  /// Callback invoked when the user taps a configured editing action on selected text.
  final ValueChanged<SelectionActionEvent>? onSelectionAction;

  /// Callback invoked when the user interacts with an existing decoration (e.g. taps a highlight).
  final ValueChanged<DecorationInteractionEvent>? onDecorationInteraction;

  /// Callback invoked when the user taps an image in the EPUB.
  ///
  /// Fired on iOS and Android (when supported). On Android the kotlin-toolkit
  /// does not yet expose a target-element API, so this callback never fires
  /// there. On iOS it uses swift-toolkit's `ImageContentElement` SPI.
  final ValueChanged<ImageTapEvent>? onImageTapped;

  /// Native context menu actions shown when text is selected.
  final List<SelectionAction> selectionActions;

  /// Static font families whose faces are bundled as Flutter assets.
  final List<ReaderFontFamily> fontFamilyDeclarations;

  /// Controls which system-provided actions appear in the text selection menu.
  ///
  /// If `null` (the default), all platform defaults are shown (Copy, Share, etc.).
  /// If an empty set, only custom [selectionActions] are shown.
  /// Otherwise, only the specified system actions are included.
  ///
  /// Note: [DefaultSelectionAction.translate] is iOS-only; [DefaultSelectionAction.selectAll]
  /// is Android-only. Unsupported values for a platform are silently ignored.
  final Set<DefaultSelectionAction>? allowedDefaultActions;

  /// Accessibility label for the backward navigation semantic region.
  final String goBackwardSemanticLabel;

  /// Accessibility label for the forward navigation semantic region.
  final String goForwardSemanticLabel;

  /// Accessibility label for the controls toggle semantic region.
  final String toggleShowControlsSemanticLabel;

  /// Number of resource positions to preload before the current one. Default `2`.
  /// Higher values smooth out backward navigation at the cost of memory; consider
  /// increasing for local publications and lowering for remote ones.
  ///
  /// iOS only. kotlin-toolkit does not expose this on its public navigator
  /// configuration, so the value is ignored on Android.
  final int preloadPreviousPositionCount;

  /// Number of resource positions to preload after the current one. Default `6`.
  /// See [preloadPreviousPositionCount] for tradeoffs and platform support.
  final int preloadNextPositionCount;

  @override
  State<StatefulWidget> createState() => _ReadiumReaderWidgetState();
}

class _ReadiumReaderWidgetState extends State<ReadiumReaderWidget> implements ReadiumReaderWidgetInterface {
  static final _log = ReadiumLog.tag('ReaderWidget');
  static const _wakelockTimerDuration = Duration(minutes: 30);

  Timer? _wakelockTimer;
  ReadiumReaderChannel? _channel;
  ReaderPlatformViewLifecycle? _platformLifecycle;
  bool wasDestroyed = false;
  bool isReady = false;

  final _readium = FlutterReadiumPlatform.instance;

  mq.Orientation? _lastOrientation;
  late final _orientationAlignment = ReaderOrientationAlignment(
    onError: (error, stack) {
      _log.e(error, data: '旋转后的阅读位置校正失败', stackTrace: stack);
      if (mounted && !wasDestroyed) widget.onReaderError?.call('LocatorUnavailable');
    },
  );
  late Widget _readerWidget;

  EPUBPreferences? get _defaultPreferences => _readium.defaultPreferences;

  bool _scrollMode = false;

  /// Last time that the controls were hidden due to a touch, used to guess whether a tap was caused
  /// by such a touch.
  DateTime? _lastTouchHideControls;

  @override
  void initState() {
    super.initState();
    _log.d('ReadiumReaderWidget init');

    _readerWidget = _buildNativeReader();
    _enableWakelock();
    _setCurrentWidgetInterface();
    _scrollMode = _defaultPreferences?.scroll ?? false;
  }

  @override
  void dispose() {
    _log.d('ReadiumReaderWidget dispose');
    _orientationAlignment.dispose();
    _cleanup();
    wasDestroyed = true;
    final lifecycle = _platformLifecycle;
    if (lifecycle != null) {
      unawaited(
        lifecycle.dispose().then(
          (_) => widget.onReaderDisposed?.call(),
          onError: (Object error, StackTrace stack) {
            _log.e(error, data: '原生阅读视口关闭失败', stackTrace: stack);
            widget.onReaderError?.call('ReaderDisposalFailed');
          },
        ),
      );
    } else {
      widget.onReaderDisposed?.call();
    }
    _lastOrientation = null;

    _disableWakelock();

    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    _onOrientationChangeWorkaround(MediaQuery.orientationOf(context));
    var userSwipe = false;

    final readingProgression = widget.publication.metadata.readingProgression;
    // TODO: this presumes that ReadingProgression value btt or vertical scroll using btt is not ever used
    final leftUpLabel = readingProgression == ReadingProgression.rtl && !_scrollMode
        ? widget.goForwardSemanticLabel
        : widget.goBackwardSemanticLabel;
    final rightDownLabel = readingProgression == ReadingProgression.rtl && !_scrollMode
        ? widget.goBackwardSemanticLabel
        : widget.goForwardSemanticLabel;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          width: _scrollMode ? null : 70,
          height: _scrollMode ? 100 : null,
          right: _scrollMode ? 0 : null,
          bottom: _scrollMode ? null : 0,
          child: _buildSemanticsPrevNextPage(
            label: leftUpLabel,
            toNextPage: false,
          ),
        ),
        // TODO: This presumes there is only one semantic label, for when the different toggles
        Positioned.fill(
          child: _buildSemanticsToggleFullScreen(
            label: widget.toggleShowControlsSemanticLabel,
          ),
        ),
        Positioned(
          top: _scrollMode ? null : 0,
          right: 0,
          width: _scrollMode ? null : 70,
          height: _scrollMode ? 100 : null,
          left: _scrollMode ? 0 : null,
          bottom: 0,
          child: _buildSemanticsPrevNextPage(
            label: rightDownLabel,
            toNextPage: true,
          ),
        ),
        ExcludeSemantics(
          child: Listener(
            onPointerDown: (final _) {
              _enableWakelock();
            },
            onPointerMove: (final event) {
              if (!widget.handlePointerControls || userSwipe) {
                return;
              }

              userSwipe = event.delta.distance > 3.0;

              if (userSwipe) {
                _onInteraction();
              }
            },
            onPointerUp: (final event) async {
              if (!widget.handlePointerControls) return;
              if (userSwipe) {
                /// Wait for page animation to complete.
                await Future.delayed(const Duration(seconds: 1));
              } else {
                final dx = event.position.dx;

                if (dx < 70.0 || ((context.size?.width ?? 0) - dx) < 70.0) {
                  // edge tap
                  _onInteraction();
                } else {
                  // center tap
                  _toggleControls();
                }
              }

              userSwipe = false;
            },

            child: _readerWidget,
          ),
        ),
        if (!isReady && widget.loadingWidget != null) Positioned.fill(child: widget.loadingWidget!),
      ],
    );
  }

  @override
  Future<void> go(
    final Locator locator, {
    required final bool isAudioBookWithText,
    final bool animated = false,
  }) async {
    _log.d(() => 'Go to $locator');

    await _channel?.go(
      locator,
      animated: animated,
      isAudioBookWithText: isAudioBookWithText,
    );

    _log.d('Go to locator completed');
  }

  @override
  Future<void> goBackward({final bool animated = true}) async => _channel?.goBackward(animated: animated);

  @override
  Future<void> goForward({final bool animated = true}) async => _channel?.goForward(animated: animated);

  @override
  Future<void> setEPUBPreferences(EPUBPreferences preferences) async {
    await _channel?.setEPUBPreferences(preferences);

    _scrollMode = preferences.scroll ?? false;
  }

  @override
  Future<void> setPDFPreferences(PDFPreferences preferences) async {
    _channel?.setPDFPreferences(preferences);
  }

  @override
  Future<void> applyDecorations(
    String id,
    List<ReaderDecoration> decorations,
  ) async {
    await _channel?.applyDecorations(id, decorations);
  }

  Widget _buildNativeReader() {
    final publication = widget.publication;

    _log.d(publication.identifier);

    final defaultPreferences = _defaultPreferences?.toJson();

    final creationParams = <String, dynamic>{
      'pubIdentifier': publication.identifier,
      'sessionId': widget.sessionId,
      'handleInternalLinks': widget.handleInternalLinks,
      'preferences': defaultPreferences,
      'initialLocator': widget.initialLocator == null ? null : json.encode(widget.initialLocator),
      'preloadPreviousPositionCount': widget.preloadPreviousPositionCount,
      'preloadNextPositionCount': widget.preloadNextPositionCount,
      'fontFamilyDeclarations': widget.fontFamilyDeclarations.map((font) => font.toMap()).toList(),
      if (widget.selectionActions.isNotEmpty)
        'selectionActions': widget.selectionActions.map((a) => a.toJson()).toList(),
      if (widget.allowedDefaultActions != null)
        'allowedDefaultActions': widget.allowedDefaultActions!.map((a) => a.serialized).toList(),
    };

    _log.d('creationParams=$creationParams');

    if (Platform.isAndroid || Platform.isIOS) {
      final lifecycle = ReaderPlatformViewLifecycle(
        viewType: _viewType,
        creationParams: creationParams,
        onAllocated: _onPlatformViewCreated,
        beforeDispose: () async {
          final channel = _channel;
          await channel?.dispose();
          if (identical(_channel, channel)) _channel = null;
        },
      );
      _platformLifecycle = lifecycle;
      return ReaderPlatformView(
        lifecycle: lifecycle,
        platform: Platform.isAndroid ? TargetPlatform.android : TargetPlatform.iOS,
        onError: (error, stack) {
          _log.e(error, data: '原生阅读视口创建失败', stackTrace: stack);
          widget.onReaderError?.call('ReaderInitializationFailed');
        },
      );
    }
    return ColoredBox(
      color: const Color(0xffff00ff),
      child: Center(
        child: Text(
          'TODO — Implement ReadiumReaderWidget on ${Platform.operatingSystem}.',
        ),
      ),
    );
  }

  Future<void> _enableWakelock() async {
    _log.d('Ensure wakelock /w timer');

    WakelockPlus.enable();

    // Disable wakelock after 30 minutes of inactivity (no interaction with reader).
    _wakelockTimer?.cancel();
    _wakelockTimer = Timer(_wakelockTimerDuration, _disableWakelock);
  }

  void _disableWakelock() {
    _log.d('Disable wakelock');

    WakelockPlus.disable();
    _wakelockTimer?.cancel();
  }

  void _setCurrentWidgetInterface() {
    _log.d('Set current reader in plugin');
    // ignore: invalid_use_of_protected_member
    _readium.currentReaderWidget = this;
  }

  void _cleanup() {
    _log.d('cleanup ${_channel?.name}!');
    // ignore: invalid_use_of_protected_member
    if (identical(_readium.currentReaderWidget, this)) {
      // ignore: invalid_use_of_protected_member
      _readium.currentReaderWidget = null;
    }
  }

  Locator? _currentLocator;
  bool _reportedInitialLocator = false;

  void _onPlatformViewCreated(final int id) {
    if (wasDestroyed || !mounted) return;
    _channel = ReadiumReaderChannel(
      '$_viewType:$id',
      onReaderReady: _markReady,
      onPageChanged: (final locator) {
        if (!mounted || wasDestroyed) return;
        _log.d(() => 'onPageChanged: ${locator.toJson()}');
        _currentLocator = locator;
        widget.onLocatorChanged?.call(locator);
        _markReady();
        if (!_reportedInitialLocator) {
          _reportedInitialLocator = true;
          widget.onReaderReady?.call();
        }
      },
      onExternalLinkActivated: (link) {
        if (mounted && !wasDestroyed) widget.onExternalLinkActivated?.call(link);
      },
      onTextInteraction: (json) {
        if (mounted && !wasDestroyed) widget.onTextInteraction?.call(json);
      },
      onReaderError: (code) {
        if (mounted && !wasDestroyed) widget.onReaderError?.call(code);
      },
      onTextSelected: (event) {
        if (mounted && !wasDestroyed) widget.onTextSelected?.call(event);
      },
      onSelectionAction: (event) {
        if (mounted && !wasDestroyed) widget.onSelectionAction?.call(event);
      },
      onDecorationInteraction: (event) {
        if (mounted && !wasDestroyed) widget.onDecorationInteraction?.call(event);
      },
      onImageTapped: (event) {
        if (mounted && !wasDestroyed) widget.onImageTapped?.call(event);
      },
    );

    if (widget.selectionActions.isNotEmpty) {
      _channel!.configureSelectionActions(widget.selectionActions);
    }

    _log.d('New widget is: ${_channel?.name}');
  }

  void _markReady() {
    if (!mounted || isReady) {
      return;
    }

    setState(() {
      isReady = true;
    });
  }

  /// TODO: Remove this workaround, if the underlying issue is completely fixed in Readium.
  ///
  /// If orientation changes, fix page alignment, so it doesn't stay on a weird-looking page 5½.
  void _onOrientationChangeWorkaround(final mq.Orientation orientation) {
    if (_lastOrientation == null) {
      _lastOrientation = orientation;

      return;
    }

    if (!isReady) {
      return;
    }

    if (orientation != _lastOrientation) {
      if (_lastOrientation != null && _currentLocator != null) {
        final channel = _channel;
        _orientationAlignment.schedule(() async {
          final locator = _currentLocator;
          if (!mounted || wasDestroyed || channel == null || !identical(channel, _channel) || locator == null) return;
          _log
            ..d(
              'Orientation changed. Re-navigating to current locator to re-align page.',
            )
            ..d('locator = $_currentLocator');
          await channel.go(
            locator,
            animated: false,
            isAudioBookWithText: false, // TODO: isAudioBookWithText - we don't know atm.
          );
        });
      }

      _lastOrientation = orientation;
    }
  }

  void _toggleControls() {
    if (widget.shouldShowControls == null) return;

    final last = _lastTouchHideControls;
    final delta = last != null ? DateTime.now().difference(last) : null;
    // If we recently hid the controls due to a touch, assume that the tap is due to that same
    // touch, so don't re-show the controls.
    if (delta == null || delta > const Duration(milliseconds: 400)) {
      widget.shouldShowControls!.value = !widget.shouldShowControls!.value;
      // Debounce taps, since Readium apparently sends a double onTap on some devices.
      _lastTouchHideControls = DateTime.now();
    }
  }

  void _onInteraction() {
    if (widget.shouldShowControls?.value == true) {
      widget.shouldShowControls?.value = false;
      _lastTouchHideControls = DateTime.now();
    }

    // A user swipe / edge-tap is the unambiguous "user took manual control"
    // signal (audio-driven page turns are programmatic and never reach this
    // Listener). The native side enters narration manual mode only if narration
    // is active, so this is a no-op during plain reading.
    _channel?.notifyUserNavigation();
  }

  Widget _buildSemanticsPrevNextPage({
    required final String label,
    required final bool toNextPage,
  }) => Semantics(
    // TODO: this is not necessarily how it should be handled needs to be evaluated more
    sortKey: OrdinalSortKey(toNextPage ? 2.0 : 0.0),
    button: true,
    container: true,
    label: label,
    onTap: () => toNextPage ? _channel?.goForward() : _channel?.goBackward(),
    child: Container(color: Colors.transparent),
  );

  Widget _buildSemanticsToggleFullScreen({required final String label}) => Semantics(
    sortKey: const OrdinalSortKey(1.0),
    button: true,
    container: true,
    label: label,
    onTap: _toggleControls,
    child: Container(color: Colors.transparent),
  );
}
