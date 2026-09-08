import 'chapter_navigation.dart';

/// 阅读视口：导航编排需要渲染引擎提供的最小能力。
///
/// presentation 的 `ReaderRendererController` 是生产实现，测试用 fake——两种实现，
/// 故不是假 seam。接口只描述语义（预载、跳转、恢复滚动位置），不暴露 WebView 细节。
abstract interface class ReaderViewport {
  /// 预载一章，返回等待事件 token；无事件时返回 null。
  Future<int?> preloadChapter(ChapterPreloadRequest request);

  /// 等待预载事件完成；[tokens] 为空时立即返回。
  Future<void> waitForEvents(List<int> tokens);

  /// 把章内滚动位置恢复到 [ratio]（0–1）。
  Future<void> restoreScrollPosition(double ratio);

  /// 跳到上一章末页。
  Future<void> jumpToPreviousChapterLastPage();

  /// 跳到上一章首页。
  Future<void> jumpToPreviousChapterFirstPage();

  /// 跳到下一章首页。
  Future<void> jumpToNextChapter();

  /// 跳到本章第 [pageIndex] 页。
  Future<void> jumpToPage(int pageIndex);
}
