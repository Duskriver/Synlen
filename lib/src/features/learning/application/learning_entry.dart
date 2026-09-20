import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/services/toast_service.dart';

import '../presentation/widgets/sentence_analysis_dialog.dart';
import '../presentation/widgets/word_definition_dialog.dart';
import '../presentation/widgets/word_definition_popover.dart';

part 'learning_entry.g.dart';

/// 学习能力的对外入口：宿主提供词锚点并在重排时关闭词卡。
@riverpod
class LearningEntry extends _$LearningEntry {
  RawDialogRoute<void>? _wordRoute;
  bool _wordDismissPending = false;

  @override
  void build() {
    ref.onDispose(dismissWord);
  }

  /// [anchorRect] 为 Flutter 全局逻辑坐标；同时只允许一张词卡。
  Future<void> showWord({
    required String word,
    String? context,
    required Rect anchorRect,
    required ThemeData theme,
  }) async {
    if (_wordRoute != null) return;
    final navigator = ToastService.navigatorKey.currentState;
    final overlayBox = navigator?.overlay?.context.findRenderObject();
    if (navigator == null ||
        overlayBox is! RenderBox ||
        !overlayBox.hasSize ||
        !anchorRect.isFinite ||
        anchorRect.isEmpty) {
      return;
    }
    final localAnchor = Rect.fromPoints(
      overlayBox.globalToLocal(anchorRect.topLeft),
      overlayBox.globalToLocal(anchorRect.bottomRight),
    );
    final keepAlive = ref.keepAlive();
    final route = RawDialogRoute<void>(
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(
        navigator.context,
      ).modalBarrierDismissLabel,
      transitionDuration: MediaQuery.disableAnimationsOf(navigator.context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (routeContext, animation, secondaryAnimation) => Theme(
        data: theme,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: word,
          child: WordDefinitionPopover(
            anchorRect: localAnchor,
            child: WordDefinitionDialog(word: word, context: context ?? ''),
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
            child: child,
          ),
    );
    _wordRoute = route;
    try {
      await navigator.push(route);
      await route.completed;
    } finally {
      if (identical(_wordRoute, route)) {
        _wordRoute = null;
        _wordDismissPending = false;
      }
      keepAlive.close();
    }
  }

  /// 仅移除本入口持有的词卡；延到帧末以兼容宿主重排与销毁回调。
  void dismissWord() {
    final route = _wordRoute;
    if (route == null || _wordDismissPending) return;
    _wordDismissPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// 长按句子入口：翻译 / 语法分析 + 整句朗读。
  Future<void> showSentence({required String sentence}) async {
    appLogger.d('Sentence Selected: $sentence');
    await _showSheet(
      (controller) => SentenceAnalysisDialog(
        sentence: sentence,
        scrollController: controller,
      ),
    );
  }

  /// 用根导航器弹出底部面板；宿主无需传 BuildContext。
  Future<void> _showSheet(
    Widget Function(ScrollController controller) builder,
  ) {
    final context = ToastService.navigatorKey.currentContext;
    if (context == null) {
      appLogger.w('学习入口：导航上下文尚未就绪，忽略本次调用');
      return Future.value();
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: builder(controller),
        ),
      ),
    );
  }
}
