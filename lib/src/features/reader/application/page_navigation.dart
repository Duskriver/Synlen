/// 翻页边界判定的结果。
enum PageTurnBoundary { ok, firstPageOfBook, lastPageOfBook }

/// 判断当前是否还能翻页；越出全书首 / 末页时返回对应语义供 UI 提示。
///
/// 判定与旧实现逐字等价：currentPage >= totalPages - 1 在 totalPages 尚未
/// 测得（0）时同样视为末页，保持行为不变。
PageTurnBoundary resolvePageTurnBoundary({
  required bool isNext,
  required int currentPage,
  required int totalPages,
  required int currentSpineIndex,
  required int spineLength,
}) {
  if (isNext) {
    final atLastPage = currentPage >= totalPages - 1;
    return atLastPage && currentSpineIndex >= spineLength - 1
        ? PageTurnBoundary.lastPageOfBook
        : PageTurnBoundary.ok;
  }
  return currentPage <= 0 && currentSpineIndex <= 0
      ? PageTurnBoundary.firstPageOfBook
      : PageTurnBoundary.ok;
}

/// 章内翻页的目标页；返回 null 表示需要跨章。
int? pageTurnTargetIndex({
  required bool isNext,
  required int currentPage,
  required int totalPages,
}) {
  final target = isNext ? currentPage + 1 : currentPage - 1;
  if (target < 0 || target >= totalPages) return null;
  return target;
}
