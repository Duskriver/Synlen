import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/reader/application/reader_navigator.dart';
import 'package:synlen/src/features/reader/presentation/reader_nav_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReaderNavFeedback feedback;
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    feedback = ReaderNavFeedback(l10n: l10n, theme: ThemeData.light());
  });

  test('边界结果映射到对应文案', () {
    expect(
      feedback.messageFor(ReaderNavOutcome.firstChapter),
      l10n.firstChapterOfBook,
    );
    expect(
      feedback.messageFor(ReaderNavOutcome.lastChapter),
      l10n.lastChapterOfBook,
    );
    expect(
      feedback.messageFor(ReaderNavOutcome.firstPageOfBook),
      l10n.firstPageOfBook,
    );
    expect(
      feedback.messageFor(ReaderNavOutcome.lastPageOfBook),
      l10n.lastPageOfBook,
    );
  });

  test('目录项失败映射到对应文案', () {
    expect(
      feedback.messageFor(ReaderNavOutcome.tocItemHasNoContent),
      l10n.chapterHasNoContent,
    );
    expect(
      feedback.messageFor(ReaderNavOutcome.tocItemNotInSpine),
      l10n.chapterNotFoundInSpine,
    );
  });

  test('成功与忽略不提示', () {
    expect(feedback.messageFor(ReaderNavOutcome.moved), isNull);
    expect(feedback.messageFor(ReaderNavOutcome.ignored), isNull);
  });
}
