# Agent Note: 目录高亮状态与图片覆盖层从 ReaderScreen 拆出

Status: implemented

## Problem

`reader_screen.dart` 里有两块与装配无关的代码：目录高亮（两个 `ValueNotifier` + 从会话推导激活条目与标题的逻辑，散在 State 字段、`refreshActiveTocState`、`resolveActiveItems`、`handleScrollAnchors` 四处），以及图片查看覆盖层（`Positioned.fill` + `IgnorePointer` + `AnimatedOpacity` + `ImageViewer` 的 20 行嵌套）。

## Decision

- `ReaderTocState`（`presentation/reader_toc_state.dart`）：持有激活条目与标题两个 `ValueNotifier`，暴露 `refresh(session, spineIndex)` 与 `updateAnchors(...)`；屏幕的 `refreshActiveTocState` 只做委托。
- `ReaderImageOverlay`（`presentation/widgets/reader_image_overlay.dart`）：只吃可见性、图片地址、来源矩形与查看器依赖。

## Alternatives considered

**把目录高亮状态放进 `BookSession`** —— 放弃：会话是 application 层的数据来源，不该持有 Flutter 的 `ValueNotifier`；高亮是展示态。

**目录状态放进 application 的 `ReaderNavigator`** —— 放弃：导航状态机管位置与忙态，目录高亮依赖会话的锚点解析与 l10n 标题回退，混进去会让状态机变成"什么都管"。

**图片覆盖层留在屏幕** —— 放弃：它只依赖八个字段，抽出来才能让屏幕的 build 专注于装配。

## Consequences

- `reader_screen.dart` 由 611 行降到 582 行；目录高亮逻辑有独立单测（`reader_toc_state_test.dart`，含"重复刷新不重复通知"）。
- 屏幕少两个 `ValueNotifier` 字段与一段 20 行的覆盖层嵌套。
- 行为不变：激活条目去重、标题回退与覆盖层动画参数逐字保留。
