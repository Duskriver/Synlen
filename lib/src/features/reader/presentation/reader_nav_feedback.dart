import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../core/services/toast_service.dart';
import '../application/reader_navigator.dart';

/// 导航结果 → 用户提示。
///
/// 只有边界与失败语义需要提示（首章 / 末章、全书首末页、目录项缺内容或
/// 不在 spine 中）；`moved` 与 `ignored` 静默。
class ReaderNavFeedback {
  const ReaderNavFeedback({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  void show(ReaderNavOutcome outcome) {
    final message = switch (outcome) {
      ReaderNavOutcome.firstChapter => l10n.firstChapterOfBook,
      ReaderNavOutcome.lastChapter => l10n.lastChapterOfBook,
      ReaderNavOutcome.firstPageOfBook => l10n.firstPageOfBook,
      ReaderNavOutcome.lastPageOfBook => l10n.lastPageOfBook,
      ReaderNavOutcome.tocItemHasNoContent => l10n.chapterHasNoContent,
      ReaderNavOutcome.tocItemNotInSpine => l10n.chapterNotFoundInSpine,
      ReaderNavOutcome.moved || ReaderNavOutcome.ignored => null,
    };
    if (message == null) return;
    ToastService.showError(message, theme: theme);
  }
}
