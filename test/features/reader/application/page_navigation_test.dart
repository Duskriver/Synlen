import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/reader/application/page_navigation.dart';

/// 从 page_navigation_mixin 抽出的翻页边界与目标判定（纯函数）。
void main() {
  group('resolvePageTurnBoundary', () {
    test('中间页可翻', () {
      expect(
        resolvePageTurnBoundary(
          isNext: true,
          currentPage: 1,
          totalPages: 5,
          currentSpineIndex: 1,
          spineLength: 3,
        ),
        PageTurnBoundary.ok,
      );
      expect(
        resolvePageTurnBoundary(
          isNext: false,
          currentPage: 1,
          totalPages: 5,
          currentSpineIndex: 0,
          spineLength: 3,
        ),
        PageTurnBoundary.ok,
      );
    });

    test('末章末页向后翻到达全书末尾', () {
      expect(
        resolvePageTurnBoundary(
          isNext: true,
          currentPage: 4,
          totalPages: 5,
          currentSpineIndex: 2,
          spineLength: 3,
        ),
        PageTurnBoundary.lastPageOfBook,
      );
    });

    test('末章非末页仍可向后翻（交给跨章）', () {
      expect(
        resolvePageTurnBoundary(
          isNext: true,
          currentPage: 2,
          totalPages: 5,
          currentSpineIndex: 2,
          spineLength: 3,
        ),
        PageTurnBoundary.ok,
      );
    });

    test('首章首页向前翻到达全书开头', () {
      expect(
        resolvePageTurnBoundary(
          isNext: false,
          currentPage: 0,
          totalPages: 5,
          currentSpineIndex: 0,
          spineLength: 3,
        ),
        PageTurnBoundary.firstPageOfBook,
      );
    });

    test('未测得总页数时按旧语义视为末页', () {
      expect(
        resolvePageTurnBoundary(
          isNext: true,
          currentPage: 0,
          totalPages: 0,
          currentSpineIndex: 1,
          spineLength: 3,
        ),
        PageTurnBoundary.ok,
      );
      expect(
        resolvePageTurnBoundary(
          isNext: true,
          currentPage: 0,
          totalPages: 0,
          currentSpineIndex: 2,
          spineLength: 3,
        ),
        PageTurnBoundary.lastPageOfBook,
      );
    });
  });

  group('pageTurnTargetIndex', () {
    test('章内翻页返回相邻页', () {
      expect(
        pageTurnTargetIndex(isNext: true, currentPage: 1, totalPages: 5),
        2,
      );
      expect(
        pageTurnTargetIndex(isNext: false, currentPage: 1, totalPages: 5),
        0,
      );
    });

    test('越过末页 / 首页返回 null（交给跨章）', () {
      expect(
        pageTurnTargetIndex(isNext: true, currentPage: 4, totalPages: 5),
        isNull,
      );
      expect(
        pageTurnTargetIndex(isNext: false, currentPage: 0, totalPages: 5),
        isNull,
      );
    });

    test('总页数未测得时直接跨章', () {
      expect(
        pageTurnTargetIndex(isNext: true, currentPage: 0, totalPages: 0),
        isNull,
      );
    });
  });
}
