import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/features/reader/application/reader_settings_notifier.dart';
import 'package:synlen/src/features/reader/domain/epub_theme.dart';
import 'package:synlen/src/features/reader/domain/reader_settings.dart';

import '../application/book_session.dart';
import '../application/chapter_navigation.dart';
import '../application/book_webview_handler.dart';
import '../application/reader_viewport.dart';
import './reader_webview.dart';
import './widgets/reader_status_bar_overlay.dart';
import 'page_turn/page_turn.dart';
part 'reader_renderer_controller.dart';

class ReaderRenderer extends ConsumerStatefulWidget {
  final ReaderRendererController controller;
  final BookSession bookSession;
  final BookWebViewHandler webViewHandler;
  final String fileHash;
  final bool showControls;
  final bool isLoading;
  final bool Function(bool isNext) canPerformPageTurn;
  final Future<void> Function(bool isNext) onPerformPageTurn;
  final VoidCallback onToggleControls;
  final Future<void> Function(Future<void> Function()) runInteraction;
  final ReaderWebViewCallbacks callbacks;
  final bool shouldShowWebView;
  final EpubTheme initializeTheme;
  final ValueListenable<String> statusBarLeftContent;
  final ValueListenable<String> statusBarRightContent;

  const ReaderRenderer({
    super.key,
    required this.controller,
    required this.bookSession,
    required this.webViewHandler,
    required this.fileHash,
    required this.showControls,
    required this.isLoading,
    required this.canPerformPageTurn,
    required this.onPerformPageTurn,
    required this.onToggleControls,
    required this.runInteraction,
    required this.callbacks,
    required this.shouldShowWebView,
    required this.initializeTheme,
    required this.statusBarLeftContent,
    required this.statusBarRightContent,
  });

  bool get isVertical {
    return bookSession.direction == 1;
  }

  @override
  ConsumerState<ReaderRenderer> createState() => _ReaderRendererState();
}

class _ReaderRendererState extends ConsumerState<ReaderRenderer>
    with TickerProviderStateMixin {
  final GlobalKey _webViewKey = GlobalKey();
  final ReaderWebViewController _webViewController = ReaderWebViewController();
  ProviderSubscription<ReaderPageAnimation>? _pageAnimationSubscription;

  late final AndroidPageTurnSession _androidPageTurnSession;
  late final IOSPageTurnSession _iosPageTurnSession;

  late EpubTheme _currentTheme;
  late bool _needPageTurnAnimation;

  EdgeInsets _addSafeAreaToPadding(EdgeInsets basePadding) {
    final safePaddings = MediaQuery.paddingOf(context);
    final safeBottomPadding = max(safePaddings.bottom, 32);
    return EdgeInsets.fromLTRB(
      basePadding.left + safePaddings.left,
      basePadding.top + safePaddings.top,
      basePadding.right + safePaddings.right,
      basePadding.bottom + safeBottomPadding,
    );
  }

  EpubTheme _addSafeAreaToThemePadding(EpubTheme theme) {
    final newPadding = _addSafeAreaToPadding(theme.padding);
    return theme.copyWith(padding: newPadding);
  }

  Future<void> _updateTheme(EpubTheme theme) async {
    _currentTheme = theme;
    await _webViewController.updateTheme(
      theme.copyWith(padding: _addSafeAreaToPadding(theme.padding)),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.controller._attachState(this);
    _androidPageTurnSession = AndroidPageTurnSession(
      vsync: this,
      duration: const Duration(
        milliseconds: AppTheme.defaultAnimationDurationMs,
      ),
    );
    _iosPageTurnSession = IOSPageTurnSession();
    _currentTheme = widget.initializeTheme;
    _needPageTurnAnimation =
        ref.read(readerSettingsProvider).pageAnimation !=
        ReaderPageAnimation.none;
    _pageAnimationSubscription = ref.listenManual(
      readerSettingsProvider.select((s) => s.pageAnimation),
      (previous, next) {
        if (previous == next || !mounted) {
          return;
        }

        setState(() {
          _needPageTurnAnimation = next != ReaderPageAnimation.none;
        });
      },
    );
  }

  @override
  void dispose() {
    widget.controller._attachState(null);
    _pageAnimationSubscription?.close();
    _androidPageTurnSession.dispose();
    super.dispose();
  }

  Future<void> _performPageTurn(bool isNext) =>
      widget.runInteraction(() => _animatePageTurn(isNext));

  Future<void> _animatePageTurn(bool isNext) async {
    if (!mounted || !widget.canPerformPageTurn(isNext)) return;
    await _webViewController.waitForRender();
    if (!mounted) return;
    if (!widget.canPerformPageTurn(isNext)) return;

    if (Platform.isAndroid) {
      await _androidPageTurnSession.perform(
        webViewController: _webViewController,
        needAnimation: _needPageTurnAnimation,
        isNext: isNext,
        isVertical: widget.isVertical,
        onPerformPageTurn: widget.onPerformPageTurn,
        setState: setState,
        isMounted: () => mounted,
      );
    } else {
      await _iosPageTurnSession.perform(
        needAnimation: _needPageTurnAnimation,
        isNext: isNext,
        isVertical: widget.isVertical,
        onPerformPageTurn: widget.onPerformPageTurn,
      );
    }
  }

  bool _isBottomBlankTap(Offset localPosition) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return false;
    }

    final height = renderBox.size.height;
    final activationHeight = max(_currentTheme.padding.bottom, 48.0);

    return localPosition.dy >= height - activationHeight;
  }

  void _handleTap(TapUpDetails details) {
    if (widget.showControls) {
      widget.onToggleControls();
    } else if (_isBottomBlankTap(details.localPosition)) {
      widget.onToggleControls();
    } else if (_androidPageTurnSession.isAnimating ||
        _iosPageTurnSession.isAnimating) {
      _handleTapZone(details.localPosition.dx, details.localPosition.dy);
    } else {
      final webViewBox = _webViewKey.currentContext?.findRenderObject();
      if (webViewBox is! RenderBox || !webViewBox.hasSize) return;
      final point = webViewBox.globalToLocal(details.globalPosition);
      unawaited(
        widget.runInteraction(
          () => _webViewController.checkTapElementAt(point.dx, point.dy),
        ),
      );
    }
  }

  void _handleTapZone(double x, double y) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final width = MediaQuery.of(context).size.width;
    if (width <= 0) return;

    final ratio = x / width;
    if (ratio < 0.3) {
      if (widget.showControls) {
        widget.onToggleControls();
        return;
      }
      if (widget.isVertical) {
        _performPageTurn(true);
      } else {
        _performPageTurn(false);
      }
    } else if (ratio > 0.7) {
      if (widget.showControls) {
        widget.onToggleControls();
        return;
      }
      if (widget.isVertical) {
        _performPageTurn(false);
      } else {
        _performPageTurn(true);
      }
    } else {
      widget.onToggleControls();
    }
  }

  Future<void> _handleHorizontalDragEnd(DragEndDetails details) async {
    if (widget.showControls) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -200) {
      if (widget.isVertical) {
        await _performPageTurn(false);
      } else {
        await _performPageTurn(true);
      }
    } else if (velocity > 200) {
      if (widget.isVertical) {
        await _performPageTurn(true);
      } else {
        await _performPageTurn(false);
      }
    }
  }

  Future<void> _handleLongPressStart(LongPressStartDetails details) async {
    final webViewBox = _webViewKey.currentContext?.findRenderObject();
    if (webViewBox is! RenderBox || !webViewBox.hasSize) return;
    final point = webViewBox.globalToLocal(details.globalPosition);
    await widget.runInteraction(
      () => _webViewController.checkLongPressElementAt(point.dx, point.dy),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.shouldShowWebView ? _handleTap : null,
        onHorizontalDragEnd: widget.shouldShowWebView
            ? _handleHorizontalDragEnd
            : null,
        onLongPressStart: widget.shouldShowWebView
            ? _handleLongPressStart
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBody(),
            ReaderStatusBarOverlay(
              leftContent: widget.statusBarLeftContent,
              rightContent: widget.statusBarRightContent,
              isLoading: widget.isLoading,
              shouldShowWebView: widget.shouldShowWebView,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Platform.isAndroid
        ? _androidPageTurnSession.buildAnimatedContainer(
            context,
            _buildWebView(),
            _buildScreenshotContainer,
          )
        : _iosPageTurnSession.buildAnimatedContainer(context, _buildWebView());
  }

  Widget _buildContentWrapper(Widget child) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(
              alpha: _currentTheme.isDark ? 0.3 : 0.15,
            ),
            blurRadius: 25,
            offset: Offset.zero,
          ),
        ],
        color: _currentTheme.surfaceColor,
      ),
      child: Container(alignment: AlignmentGeometry.center, child: child),
    );
  }

  Widget _buildWebView() {
    return _buildContentWrapper(
      ReaderWebView(
        key: _webViewKey,
        bookSession: widget.bookSession,
        webViewHandler: widget.webViewHandler,
        fileHash: widget.fileHash,
        initializeTheme: _addSafeAreaToThemePadding(widget.initializeTheme),
        isLoading: widget.isLoading,
        controller: _webViewController,
        callbacks: widget.callbacks.withTap(_handleTapZone),
        shouldShowWebView: widget.shouldShowWebView,
        coverRelativePath: widget.bookSession.book?.coverPath,
        direction: widget.bookSession.direction,
      ),
    );
  }

  Widget _buildScreenshotContainer(ui.Image? screenshot) {
    if (screenshot == null) {
      return _buildContentWrapper(Container(color: _currentTheme.surfaceColor));
    }
    return _buildContentWrapper(RawImage(image: screenshot, fit: BoxFit.cover));
  }
}
