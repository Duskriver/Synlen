# Agent Note: 组合面允许依赖其他 feature 的 application 层

Status: implemented

## Problem

"feature 之间不互相 import"这条一刀切规则，与设置页的真实职责冲突：设置页本身就要聚合各 feature 的能力（备份、清缓存、密钥、音色）。当时有 5 个跨 feature 且 `presentation → data` 的违规文件，全部集中在 `settings/` 与已并入 library 的 `detail/`。

## Decision

定义**组合面（composition surface）**：只允许组合面依赖其他 feature 的 **application** 层；组合面自己的 application 层可以编排其他 feature 的 data 层；**任何 feature 的 presentation 都不得直接依赖其他 feature 的 data**。

`settings` 是当前唯一的组合面，它的 `application/` 承担跨 feature 编排：`cache_cleanup` 编排 library 与 learning 的清理、`backup_export` 编排 library 的导出、`deep_seek_connectivity` 把 data 层异常翻译成可展示结果。新增组合面必须先改本笔记，不能自行扩权。

### 追加条款：宿主对能力模块的入口例外

阅读器（宿主）调用学习（能力模块）的"点词释义 + 发音""长按句子分析 + 朗读"是产品设计本身，不是可消除的耦合；要防的是**耦合面过大**。规则补充：

- 宿主页面只依赖能力模块的 **application 入口**（`learning/application/learning_entry.dart`），不依赖其弹窗 widget；
- 宿主 application 只依赖能力模块的 **application 查询接口**（`library/application/book_queries.dart`），不依赖其仓库；
- 能力模块要读配置时只依赖配置模块的 application（`reader → settings/application`）。

这样能力模块内部怎么改（弹窗形状、仓库实现、参数）都不再波及宿主；接口的稳定面收窄成一个方法签名。

## Alternatives considered

**严格隔离，把能力全部下沉 `core/`** —— 放弃：`ExportBackupService` 依赖 library 的两个仓库，下沉后形成 `core → feature`，方向倒置。

**让设置页持有各 feature 的 UI 片段** —— 放弃：presentation 互相依赖比跨层依赖更糟。

**不设规则、维持现状** —— 放弃：违规清单无法收敛，下一轮开发继续各自伸手。

## Consequences

- 各 feature 内部的 `presentation → data` 仍按规范逐条修复，不受本例外影响。
- 新增跨 feature 边之前先读本笔记，并让 `dart run tool/layer_gates.dart` 通过（当前边表由该脚本 `--list` 输出）。
