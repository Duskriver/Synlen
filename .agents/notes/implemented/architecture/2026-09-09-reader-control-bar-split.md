# Agent Note: 阅读器底部控制条拆成 widget，翻页边界复用 application 判定

Status: implemented

## Problem

`control_panel.dart` 477 行里，控件状态机与底部控制条混在一起，并且翻页 / 翻章的可用性判断自己写了一整套：八个 `_shouldHandleOn*` getter 两两重复（`_shouldHandleOnPreviousChapter` 与 `_shouldHandleOnPreviousPage` 表达式逐字相同），语义上与 `reader/application/page_navigation.dart` 的 `resolvePageTurnBoundary` 等价，却各自维护。

## Decision

- 底部控制条拆成 `ReaderBottomBar`（`widgets/reader_bottom_bar.dart`）：目录入口、上一页 / 下一页按钮（长按每 500ms 连续翻）、样式面板入口与长按计时器都归它；`ControlPanel` 只传标签、可用性与回调。
- 页码格式化 `formatPageIndicator` 随控制条走，成为可单测的顶层函数。
- 控制条只消费宿主传入的可用性与回调。旧 application 页码边界已由 [Readium 引擎决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)替代，翻页交给原生 Navigator。

## Alternatives considered

**保留八个 getter，只拆 widget** —— 放弃：重复逻辑会继续分叉，且 `ReaderNavigator` 已经用了同一判定，两处对不上就是缺陷。

**让 `ReaderBottomBar` 自己读 provider 算可用性** —— 放弃：可用性来自当前阅读位置（章节 / 页码），那是宿主的输入；控制条只该知道"能不能"，不该知道为什么。

**把长按计时器留在 ControlPanel** —— 放弃：计时器只服务按钮的连续翻页，跟着按钮走才能让控制条自洽。

## Consequences

- 底部控制条有 widget test 覆盖禁用态、点击与长按连发。
- 计时器跟随按钮销毁，控制条不持有出版物或分页状态。
