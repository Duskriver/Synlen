# Agent Note: 导航结果到提示的映射移出 ReaderScreen

Status: implemented
Archived: 2026-09-20

## Problem

`reader_screen.dart` 的 `_showNavOutcome` 把八种导航结果映射到 l10n 文案并弹 toast：这是纯映射，却占着屏幕 15 行，且与 `ReaderNavigator` 的结果枚举定义分离，改枚举要回屏幕改分支。

## Decision

`ReaderNavFeedback`（`presentation/reader_nav_feedback.dart`）持有 l10n 与主题，`show(outcome)` 负责映射与提示；`moved` 与 `ignored` 静默。屏幕的 `_showNavOutcome` 只做构造与调用。

## Alternatives considered

**留在屏幕，只改成方法表** —— 放弃：映射表会与 `ReaderNavigator` 的枚举一起演进，独立类型便于按枚举补全分支。

**把映射放进 `ReaderNavigator`** —— 放弃：application 层不该持有 l10n 与 toast。

## Consequences

- 屏幕少 8 行分支与 l10n 依赖的直接使用；映射集中在一处，枚举新增分支时编译期即可发现遗漏。
- 行为不变：提示文案、错误样式与"成功 / 忽略不提示"的语义逐字保留。
