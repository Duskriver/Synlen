import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/services/toast_service.dart';

import '../presentation/widgets/sentence_analysis_dialog.dart';
import '../presentation/widgets/word_definition_dialog.dart';

part 'learning_entry.g.dart';

/// 学习能力的对外入口：宿主（阅读器）只依赖这两个方法，
/// 弹窗形状、滚动与生命周期留在学习模块内部。
@riverpod
class LearningEntry extends _$LearningEntry {
  @override
  void build() {}

  /// 点词入口：LLM 释义 + TTS 发音。
  Future<void> showWord({required String word, String? context}) async {
    appLogger.d('Word Tapped: $word');
    await _showSheet(
      (controller) => WordDefinitionDialog(
        word: word,
        context: context ?? '',
        scrollController: controller,
      ),
    );
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
