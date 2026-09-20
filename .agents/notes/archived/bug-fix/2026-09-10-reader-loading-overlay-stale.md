# Agent Note: 阅读器加载遮罩订阅导航状态

Status: implemented
Archived: 2026-09-20

## Problem

点「开始阅读 / 继续阅读」后白屏，再点一下屏幕内容瞬间出现。实测 613MB 的 EPUB 稳定复现，小书（TXT）不复现。

根因是竞态：`ReaderStage.build` 直接读 `navigator.state.value.isLoading` 传给 `ReaderRenderer`，但读取处没有包 `ListenableBuilder`。加载完成时 `ReaderNavigator` 把 `isLoading` 翻成 false（`reader_navigator.dart` 的 `load()` 收尾），舞台不重建，白色遮罩（`ReaderWebView` 里的 `AnimatedOpacity`）就一直盖着。点屏幕触发 `toggleControls` → `setState` 才重建、遮罩淡出——这就是"点一下才出内容"。小书加载快，路由动画完成与 `_loadBook` 收尾的两次 `setState` 都落在状态落定之后，碰巧掩盖了问题；大书加载慢，setState 发完状态才翻，就卡死了。

## Decision

`ReaderStage` 里 `ReaderRenderer` 包在监听 `navigator.state` 的 `ListenableBuilder` 中，`isLoading || isRefreshingTheme` 在 builder 内取值。忙态的拥有者仍是 `ReaderNavigator`，舞台依然不持有状态——只是把读取从"build 时快照"改为"订阅"。

## Alternatives considered

**在 `ReaderNavigator` 翻状态时回调屏幕 `setState`** —— 放弃：把 presentation 的重建职责漏进 application 层，违反分层。

**让整个 `ReaderStage` 重建** —— 放弃：`ControlPanel` 已有自己的 `ListenableBuilder`，舞台级重建范围更大且无必要。

**在 WebView attach 后强制刷帧**（`scheduleFrame` / 切 `useHybridComposition`）—— 放弃：那是把它当平台视图首帧不上屏来治；实测遮罩状态才是病根，且 `useHybridComposition: false` 是翻页截图的前提，不能动。

## Consequences

- 大书首开 / 继续阅读不再需要多点一下；加载结束遮罩自行淡出。
- 修复了[舞台拆分](../architecture/2026-09-09-reader-stage.md)引入的订阅缺口；该笔记的"行为不变"结论随之更新。
- `reader_navigator.dart` 与 `ReaderWebView` 未动；分层不变（仍是 presentation 订阅 application 暴露的 `ValueNotifier`）。

## Testing

模拟器（Synlen_Test）实测：导入 613MB《Essential Cell Biology》，「继续阅读」进入后不再白屏，遮罩加载完自动消失；翻页、目录跳章、点词查词回归正常。
