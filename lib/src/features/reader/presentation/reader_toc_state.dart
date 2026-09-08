import 'package:flutter/foundation.dart';

import '../../library/domain/book_manifest.dart';
import '../application/book_session.dart';

/// 阅读器目录高亮状态：当前章节的激活条目与标题。
///
/// 状态由会话（spine 位置、滚动锚点）推导，宿主在位置或锚点变化时调用
/// [refresh] / [updateAnchors]；两个 [ValueNotifier] 供目录抽屉与状态栏订阅。
class ReaderTocState {
  final ValueNotifier<Set<TocItem>> activeItems = ValueNotifier(<TocItem>{});
  final ValueNotifier<String> activeTitle = ValueNotifier('');

  /// 按当前 spine 位置刷新激活条目与标题；无激活条目时回退到书名。
  void refresh(BookSession session, int spineIndex) {
    final items = session.resolveActiveItems(spineIndex);
    if (!setEquals(activeItems.value, items)) {
      activeItems.value = items;
    }
    final title = items.isNotEmpty
        ? items.last.label
        : session.book?.title ?? '';
    if (activeTitle.value != title) {
      activeTitle.value = title;
    }
  }

  /// 滚动锚点变化：更新会话锚点后刷新。
  void updateAnchors(
    BookSession session,
    int spineIndex,
    List<String> anchorIds,
  ) {
    session.updateActiveAnchors(anchorIds);
    refresh(session, spineIndex);
  }

  void dispose() {
    activeItems.dispose();
    activeTitle.dispose();
  }
}
