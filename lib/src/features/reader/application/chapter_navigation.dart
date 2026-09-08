import 'book_session.dart';

/// 预载窗口中的一章。
class ChapterPreloadRequest {
  const ChapterPreloadRequest({
    required this.index,
    required this.slot,
    required this.url,
    required this.anchors,
    required this.properties,
  });

  final int index;
  final ChapterSlot slot;
  final String url;
  final List<String> anchors;
  final String? properties;
}

/// 章节在预载窗口中的位置。
enum ChapterSlot { current, previous, next }

/// 计算翻章时的预载窗口：当前章 + 前后邻居，越界自动省略。
///
/// 顺序与渲染器调用顺序一致：当前 → 上一章 → 下一章。
List<ChapterPreloadRequest> planChapterPreload(
  BookSession session, {
  required int index,
  String anchor = 'top',
}) {
  if (session.spine.isEmpty || index < 0 || index >= session.spine.length) {
    return const [];
  }

  ChapterPreloadRequest request(int i, ChapterSlot slot, String slotAnchor) {
    return ChapterPreloadRequest(
      index: i,
      slot: slot,
      url: session.getSpineItemUrl(i, slotAnchor),
      anchors: session.getAnchorsForSpine(session.spine[i].href),
      properties: session.getSpineProperties(i),
    );
  }

  return [
    request(index, ChapterSlot.current, anchor),
    if (index > 0) request(index - 1, ChapterSlot.previous, 'top'),
    if (index < session.spine.length - 1)
      request(index + 1, ChapterSlot.next, 'top'),
  ];
}

/// 翻到新章后对单个邻居的预载请求；越界返回 null。
ChapterPreloadRequest? planNeighbourPreload(
  BookSession session, {
  required int index,
  required bool forward,
}) {
  final target = forward ? index + 1 : index - 1;
  if (session.spine.isEmpty || target < 0 || target >= session.spine.length) {
    return null;
  }
  return ChapterPreloadRequest(
    index: target,
    slot: forward ? ChapterSlot.next : ChapterSlot.previous,
    url: session.getSpineItemUrl(target),
    anchors: session.getAnchorsForSpine(session.spine[target].href),
    properties: session.getSpineProperties(target),
  );
}

/// 翻章期间忽略新的导航请求：加载中、主题刷新中或正在翻章。
bool shouldIgnoreChapterNavigation({
  required bool isWebViewLoading,
  required bool updatingTheme,
  required bool isChangingChapter,
}) => isWebViewLoading || updatingTheme || isChangingChapter;
