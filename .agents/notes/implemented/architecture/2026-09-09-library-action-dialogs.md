# Agent Note: 书架动作把对话框拆成独立 widget

Status: implemented

## Problem

`library_actions_mixin.dart` 423 行里，动作方法与对话框内容混在一起：删除确认、新建分组输入、恢复来源选择三段 `AlertDialog` 内联在动作方法里。这些对话框只是 l10n 文案加两个按钮，却被埋在业务方法中间，既无法单独复用，也让动作方法的意图被 30 行 widget 代码淹没。

## Decision

三个对话框拆成 `presentation/widgets/` 下的独立 widget：`DeleteBooksConfirmDialog`、`GroupNamePromptDialog`、`RestoreSourceDialog`（`RestoreBackupSource` 枚举随它一起搬家）。动作方法只留 `showDialog` 调用与结果处理。

## Alternatives considered

**把整段编排下沉到 `library/application`** —— 放弃：动作方法的主体是"弹窗 → 拿结果 → 调 application → 提示"，弹窗必须在 presentation；下沉只能得到一层需要回调 UI 的假编排。

**连 `showEditGroupDialog` 一起拆** —— 放弃：它的"删除分组"按钮在弹窗内部直接调 `bookshelfProvider` 并弹提示，拆成 widget 会改变错误提示的挂载时机；留待与 bookshelf 动作整理一起做。

**继续内联，只加分区注释** —— 放弃：注释不减少行数，也无法让对话框被其它入口复用。

## Consequences

- `library_actions_mixin.dart` 由 423 行降到 371 行，library 的超 400 行清单少一项。
- 三个对话框成为可独立渲染的 widget，后续 widget test 可直接 pump 它们。
- 行为不变：返回类型、取消语义与 l10n 文案逐字保留。
