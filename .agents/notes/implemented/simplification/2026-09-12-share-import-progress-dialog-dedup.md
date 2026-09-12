# Agent Note: 分享导入进度对话框去重

Status: implemented

## Problem

同一份"导入进度聚合 + 完成提示"对话框曾存在两份逐字节相同的实现：`lib/src/global_share_handler.dart` 的私有 `_ShareImportProgressDialog`（约 99 行）与 `lib/src/features/library/presentation/widgets/import_progress_dialog.dart` 的公开 `ImportProgressDialog`。归一化类名后 diff 为空——仅剩构造函数 `super.key` 与 state 类私有的差异。两边各持有八个相同的状态字段，`_onData` / `_onError` / `_onDone` 与 `build` 的参数全部一致。改提示文案或计数逻辑必须同步改两处。

## Decision

分享入口直接复用公开的 `ImportProgressDialog`：`lib/src/global_share_handler.dart` 的 `_runImportPipeline` 在 `showDialog` 的 builder 里构造 `ImportProgressDialog(stream: stream, l10n: l10n)`，私有副本 `_ShareImportProgressDialog` 已删除，净删约 100 行。`ImportProgressDialog` 本身未改动，现有两个调用点：`lib/src/global_share_handler.dart`（分享/"用其他应用打开"）与 `lib/src/features/library/presentation/mixins/library_actions_mixin.dart`（书架导入）。`tool/layer_gates.dart` 对 `lib/src/` 根级文件不限制该 import。

## Alternatives considered

**抽到 `core/widgets/` 供两边共用** —— 落败：library 是主要使用方，分享 handler 本就依赖 library，方向反了只会给 core 增加无共享收益的负担。

**把 library 的实现挪进 `global_share_handler.dart`** —— 落败：提案期以为 library 侧有三个使用场景（导入、恢复、分享）；核实后事实是 `ImportProgressDialog` 只有 `library_actions_mixin.dart` 一个调用点，恢复流程用的是有意分叉的独立变体 `RestoreProgressDialog`（`lib/src/features/library/presentation/widgets/restore_progress_dialog.dart`，多了 `_hasFailed`/`_versionTooNew` 字段以解释 `BackupImportProgress`）。即便如此，把实现挪进分享入口仍会让 library 的 widgets 依赖分享入口，拉长依赖链。

## Consequences

两份实现合并为一处，分享侧与书架侧共用 `ImportProgressDialog`。`test/global_share_handler_test.dart` 断言 `find.byType(ProgressDialog)`，与具体宿主类解耦，复用公开实现后原样通过；`flutter analyze` 零 error 零 warning。

残余风险：分享侧与导入侧的完成提示未来需求分叉。真出现时分叉点参数化再拆；合并前两份逐字节相同，尚无分叉迹象。

## Dev Note

None.
