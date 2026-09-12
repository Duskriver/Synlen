# Agent Note: 单 feature 使用的 core widget 迁回

Status: implemented

## Problem

core/ 下沉规则要求共享能力被 ≥2 个 feature 使用（见 [架构文档](../../../../docs/architecture.md)），但 `lib/src/core/widgets/` 下 7 个 widget 各只服务一个 feature，占据 core 的注意力与门禁成本。合规对照组：`segmented_option_chip` / `theme_variant_chip`（reader + settings 使用）、`book_cover`（library + reader 使用）。

## Decision

7 个 widget 移回所属 feature 的 `presentation/widgets/`，`core/widgets/` 剩余 widget 全部被 ≥2 个 feature 使用：

- `expandable_fab.dart` → `lib/src/features/library/presentation/widgets/`（仅 library 使用）
- `expandable_text.dart` → `lib/src/features/library/presentation/widgets/`（仅 library 使用）
- `middle_ellipsis_two_lines_text.dart` → `lib/src/features/library/presentation/widgets/`（仅 library 使用）
- `integer_stepper.dart` → `lib/src/features/reader/presentation/widgets/`（仅 reader 使用）
- `labeled_switch_tile.dart` → `lib/src/features/reader/presentation/widgets/`（仅 reader 使用）
- `settings_section_title.dart` → `lib/src/features/reader/presentation/widgets/reader_section_title.dart`，类改名 `SettingsSectionTitle` → `ReaderSectionTitle`（原命名错位：settings feature 零命中，实际仅 reader 使用）
- `settings_sub_label.dart` → `lib/src/features/reader/presentation/widgets/reader_sub_label.dart`，类改名 `SettingsSubLabel` → `ReaderSubLabel`

5 个调用文件的 import 同步更新为同目录相对路径；`test/` 与 `integration_test/` 对这 7 个 widget 零引用，未动。

## Alternatives considered

**硬造第二使用方提升到 ≥2** —— 落败：没有真实需求的共享是反向泛化，与 core 下沉规则的初衷相反。

**留在 core、放宽规则** —— 落败：规则失去约束力，core 会重新膨胀，后续评审失去判据。

## Consequences

- 7 个文件已移出 `core/widgets/`，剩余 widget（`book_cover`、`segmented_option_chip`、`theme_variant_chip`、`toast_bubble`）均满足 ≥2 feature 使用。
- `settings_section_title` / `settings_sub_label` 的 reader 语义改名消除了命名错位；类名、文件名、调用点三处一致。
- 移动文件用 `git mv` 保留历史；迁入文件内 settings/core 语境的 dartdoc 已改写为阅读器语义的中文注释。
- `tool/layer_gates.dart`、`flutter analyze`、`flutter test`（全量 471 通过）通过；core→feature 的依赖边随迁移减少。`tool/doc_gates.dart` 对本篇笔记零问题（同期工作区另有一篇无关笔记未过门禁）。
- 风险已消化：命名改动波及 2 个文件共 9 处调用点，已全部更新；移动打断在途分支的风险通过选择当前空闲窗口规避。

## Dev Note

None.
