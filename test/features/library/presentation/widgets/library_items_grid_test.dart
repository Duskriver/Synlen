import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/core/database/app_database.dart';
import 'package:synlen/src/features/library/application/bookshelf_notifier.dart';
import 'package:synlen/src/features/library/domain/book_format.dart';
import 'package:synlen/src/features/library/presentation/widgets/book_grid_item.dart';
import 'package:synlen/src/features/library/presentation/widgets/library_items_grid.dart';

ShelfBook buildBook(int id, String title) => ShelfBook(
  id: id,
  fileHash: 'hash$id',
  title: title,
  author: '作者',
  authors: const ['作者'],
  subjects: const [],
  totalChapters: 3,
  epubVersion: '3.0',
  format: BookFormat.epub,
  importDate: 0,
  direction: 0,
  currentChapterIndex: 0,
  readingProgress: 0,
  updatedAt: 0,
  isFinished: false,
  isDeleted: false,
);

void main() {
  Future<void> pumpGrid(
    WidgetTester tester,
    BookshelfState state,
    List<ShelfBook> books,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [LibraryItemsGrid(state: state, books: books)],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('空书架显示空态文案', (tester) async {
    await pumpGrid(tester, BookshelfState.bookshelfState(books: const []), []);

    expect(find.textContaining('分类'), findsWidgets);
    expect(find.byType(BookGridItem), findsNothing);
  });

  testWidgets('有书时渲染网格项', (tester) async {
    final books = [buildBook(1, '第一本'), buildBook(2, '第二本')];
    await pumpGrid(tester, BookshelfState.bookshelfState(books: books), books);

    expect(find.byType(BookGridItem), findsNWidgets(2));
    expect(find.text('第一本'), findsOneWidget);
  });

  testWidgets('紧凑视图模式仍渲染全部书籍', (tester) async {
    final books = [buildBook(1, '第一本')];
    await pumpGrid(
      tester,
      BookshelfState.bookshelfState(books: books, viewMode: ViewMode.compact),
      books,
    );

    expect(find.byType(BookGridItem), findsOneWidget);
  });
}
