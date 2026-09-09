# Agent Note: 阅读区舞台从 ReaderScreen 拆出

Status: implemented

## Problem

`reader_screen.dart` 的 build 里有 90 行纯装配：`Container` 包着 `Stack`，把导航状态、渲染器回调与控制面板的六个翻页 / 翻章动作塞进 `ReaderRenderer` 与 `ControlPanel`。屏幕因此同时是状态机宿主、生命周期宿主与视图装配点。

## Decision

`ReaderStage`（`presentation/widgets/reader_stage.dart`）只做装配：吃 `BookSession`、`ReaderNavigator`、渲染器控制器、内容供给处理器、回调值对象 `ReaderWebViewCallbacks` 与动作值对象 `ReaderPanelActions`（六个翻页 / 翻章回调），自身不持有状态。屏幕保留 `Scaffold`、目录抽屉、图片覆盖层与生命周期。

## Alternatives considered

**把 `Scaffold` 与抽屉一起搬进舞台** —— 放弃：抽屉开合要驱动音量键拦截，`Scaffold` 键与 `onDrawerChanged` 属于宿主生命周期。

**让舞台自己读 provider 拿导航状态** —— 放弃：舞台是纯视图，位置与忙态的真相在 `ReaderNavigator`，经参数传入才能保持单向。

**继续留在屏幕** —— 放弃：装配与生命周期混在一处，任何一方改动都要读整段 build。

## Consequences

- `reader_screen.dart` 由 579 行降到 548 行；舞台是纯 `StatelessWidget`，可单独 pump。
- 控制面板动作收进 `ReaderPanelActions`，面板参数不再逐个穿透。
- 加载态判定、标题回退与六个动作的语义逐字保留；但 `ReaderRenderer` 对 `navigator.state` 的读取当时是 build 时快照，导致加载遮罩不随状态刷新，已由[阅读器加载遮罩订阅导航状态](../bug-fix/2026-09-10-reader-loading-overlay-stale.md)补上 `ListenableBuilder`。
