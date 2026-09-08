# ADR-0003: 组合面允许依赖其他 feature 的 application 层

2026-09-08 决定：为「组合面」（composition surface）确立一条明确的跨 feature 协调入口，替代 §1「feature 之间不互相 import」的一刀切。

## Status

accepted

## Context

`TECH_DEBT.md §1` 记录的 10 个文件里，有 5 个是**跨 feature 且 presentation → data**：

- `settings/presentation/widgets/backup_tile.dart` → `library/data/services/export_backup_service.dart`
- `settings/presentation/widgets/clean_cache_tile.dart` → `library/data` + `learning/data`
- `settings/presentation/widgets/settings_ai_service_section.dart` → `learning/data`
- `detail/presentation/book_detail_helpers.dart` → `library/data`
- `detail/presentation/book_detail_screen.dart` → `library/data`

设置页的职责本身就是**聚合各 feature 的能力**（备份、清缓存、密钥、音色）。按「feature 互不 import」严格执行只有两条路：把这些能力全部下沉 `core/`（core 会反过来依赖 feature 的仓库，方向倒置），或让设置页持有各 feature 的 UI 片段（presentation 互相依赖，更糟）。

## Considered Options

1. **严格隔离，全部下沉 core**：`ExportBackupService` 依赖 library 的两个仓库，下沉后 `core → feature`，违背依赖方向。放弃。
2. **组合面例外**（选定）：定义组合面，只允许它依赖其他 feature 的 **application** 层；组合面自己的 application 层可以编排其他 feature 的 data 层；**任何 feature 的 presentation 都不得直接依赖其他 feature 的 data**。
3. **不设规则，维持现状**：违规清单无法收敛，下一轮开发继续各自伸手。放弃。

## Consequences

- `settings` 是当前唯一的组合面；新增组合面必须在此 ADR 追加，不能自行扩权。
- `settings/application/` 承担跨 feature 编排：`cache_cleanup` 编排 library 与 learning 的清理、`backup_export` 编排 library 的导出、`deep_seek_connectivity` 把 data 层异常翻译成可展示结果。
- `detail` 不属于组合面：它的业务是「一本书的详情」，归属 library，按 `TECH_DEBT §1` 的修复方向并入 library，不适用本例外。
- 各 feature 内部的 `presentation → data`（reader、library 自身）仍按规范逐条修复，不受本 ADR 影响。

## 2026-09-08 追加：宿主对能力模块的入口例外

阅读器（宿主）调用学习（能力模块）的「点词释义 + 发音」「长按句子分析 + 朗读」是产品设计本身，不是可消除的耦合；读者真正要防的是**耦合面过大**。规则补充：

- 宿主页面只依赖能力模块的 **application 入口**（`learning/application/learning_entry.dart`），不依赖其弹窗 widget；
- 宿主 application 只依赖能力模块的 **application 查询接口**（`library/application/book_queries.dart`），不依赖其仓库；
- 能力模块要读配置时只依赖配置模块的 application（`reader → settings/application`）。

这样能力模块内部怎么改（弹窗形状、仓库实现、参数）都不再波及宿主；接口的稳定面收窄成一个方法签名。
