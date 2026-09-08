# Agent Note: 阅读导航下沉 application 并收敛为单一状态机

Status: implemented

## Problem

`reader/presentation` 是最大的 UI 层，其中 `spine_navigation` 与 `page_navigation` 两个 part mixin 承载真正的导航逻辑：预载窗口的时序、忙态守卫、跨章跳转、页码与总页数记账。它们通过 `ReaderViewState`（6 个 `ValueNotifier` 复制 6 个字段）与 `_ReaderScreenState` 的 getter / setter 互相借用状态，且是 part 文件，单测无从注入渲染引擎。

## Decision

`ReaderNavigator`（reader/application）是导航状态机与位置状态的唯一拥有者：

- 状态 `ReaderNavState`（章节序号、章内页、总页数、加载中、翻章中、主题刷新中）经一个 `ValueNotifier` 暴露；忙态判定复用 `shouldIgnoreChapterNavigation`。
- 方法返回 `ReaderNavOutcome`（moved / ignored / firstChapter / lastChapter / firstPageOfBook / lastPageOfBook / tocItemHasNoContent / tocItemNotInSpine），文案由 presentation 映射 l10n。
- 渲染引擎经 `ReaderViewport` 接口注入：`preloadChapter` / `waitForEvents` / `restoreScrollPosition` / 三个跨章跳转 / `jumpToPage`。`ReaderRendererController` 是生产实现，测试用 fake。
- 预载后的 30ms 渲染沉降等待改为构造参数 `settleDelay`，默认值不变。

`spine_navigation_mixin` 与 `page_navigation_mixin` 删除，`ReaderViewState` 删除；TOC 高亮随后收进 `ReaderTocState`，页码显示留在 presentation 的 `ValueNotifier`。

## Alternatives considered

**让 navigator 直接依赖 `ReaderRendererController`** —— 放弃：它在 presentation，application 依赖 presentation 是反向依赖，且无法在单测里替换渲染引擎。

**把 mixin 改成独立 controller 但留在 presentation** —— 放弃：位置与忙态仍散在 widget 层，"预载窗口顺序""忙态忽略"这类编排测不到。

**把渲染器接口定义在 presentation 再由 navigator 引用** —— 放弃：seam 属于调用方，由 application 定义接口才能保持依赖方向。

## Consequences

- 导航编排（预载顺序、忙态忽略、跨章边界、页码收敛）由 `test/features/reader/application/reader_navigator_test.dart` 的 23 个用例覆盖，不再依赖真机手测。
- `reader/presentation` 仍剩 5 个 part mixin（进度显示、主题刷新、外链、图片、脚注），按同一路径继续下沉。
- `reader_screen.dart` 减少的是状态复制，UI 骨架仍在该文件。
