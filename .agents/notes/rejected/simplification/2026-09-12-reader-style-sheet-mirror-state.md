# Agent Note: 样式面板镜像状态删除

Status: rejected — 前提不成立：notifier 各 mutation 是 await 持久化在先、更新 state 在后（`reader_settings_notifier.dart:78-81`），非同步更新；镜像 + setState 双写是给拖拽控件即时反馈的有意乐观 UI，删除会导致 slider 等明显滞后

## Problem

`ReaderStyleBottomSheet`（`lib/src/features/reader/presentation/widgets/reader_style_bottom_sheet.dart:31-66`）把 `ReaderSettings` 镜像成 11 个 `late` 字段（`_scale`、`_topMargin` 等），`initState` 从 provider 抄一遍；之后每个控件的 `onChanged` 同时 `setState(() => _x = v)` 与 `_notifier.setX(v)`（如 :197-203、:212-223），两条状态每次交互手动双写。`ReaderSettingsNotifier` 的状态更新是同步的（`lib/src/features/reader/application/reader_settings_notifier.dart:78-81`），widget 直接 `ref.watch(readerSettingsProvider)` 可拿同等刷新效果——`setState` 本来就重建整个 sheet，镜像字段没有性能理由，只有同步负担。

## Proposal

删除 11 个镜像字段，`build` 内直接 watch provider，控件 `onChanged` 只调 notifier。迁移时逐字段核对初始来源，确保控件初值与 provider 当前值一致。

## Alternatives considered

**保留镜像 + 集中同步方法** —— 落败：同步点仍需手动维护，每次加控件都要记得登记；不如单一来源，天然不会漏。

**改局部 `Consumer` 刷新** —— 落败：面板本来就整体重建，局部刷新的收益不抵引入的复杂度。

## Acceptance criteria

- 该文件无双写点（无 `setState` 与 notifier 并存的 `onChanged`）。
- 11 个控件各改一次设置的行为与现状一致（手动验证）。
- `flutter analyze` 零 error 零 warning。

## Risks

个别控件依赖"字段初始值 ≠ provider 当前值"的边界：迁移时逐字段核对初始来源，发现依赖先消除再删字段。

## Dev Note

None.
