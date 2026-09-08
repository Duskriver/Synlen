# Agent Note: 分层与跨 feature 边由门禁核对

Status: implemented

## Problem

分层规则写在 [docs/architecture.md](../../../../docs/architecture.md) 与根 AGENTS.md 里，核查却靠人眼：架构文档给的是一条 `rg` 命令，它只列 import 语句，不判断发起方与所在层，也分不出合法边与违规边。曾经的 TECH_DEBT 清单在 docs 重建时删除，违规数量重新变得不可见。实测中 `reader/data` 曾直接引 library 的仓库与 parser，直到人工排查才发现。

## Decision

`tool/layer_gates.dart` 与 `tool/doc_gates.dart` 同形态：扫描 `lib/src` 的 import 边，违规即非零退出，CI 在 Flutter job 中执行。

规则：

- `presentation` 不得依赖 `data`（本 feature 与跨 feature 一致）。
- `domain` 不得依赖 `application` / `presentation` / `data`。
- 跨 feature 只允许依赖对方的 `application`（能力入口、配置读取）与 `domain`（值类型）；`data` 只允许组合面（`settings`）的 `application` 编排。
- `core/` 只能依赖 feature 的 `domain` 值类型，不得依赖其余层。

`--list` 打印当前跨 feature 边与 core → feature 边，代替人肉 grep。

为了让规则成立，路由表从 `lib/src/core/router/app_router.dart` 移到 `lib/src/app_router.dart`：它必须依赖各 feature 的 `presentation`，属于应用外壳而非共享工具箱。

## Alternatives considered

**继续用文档里的 rg 命令** —— 放弃：命令无法表达"谁引谁"与"哪一层"，违规要靠人读输出。

**引入 custom_lint 规则** —— 放弃：lint 只看单文件 AST，跨文件边要自己建索引；门禁脚本覆盖同一批规则且不增加依赖。

**保留 TECH_DEBT 清单人工维护** —— 放弃：清单会与代码漂移，且已在 docs 重建时证明维护不住。

## Consequences

- 新增跨 feature 边必须先读[组合面决策](../architecture/2026-09-08-composition-surface-cross-feature.md)，并让门禁通过；违规在提交前暴露。
- `core/` 对 feature `domain` 的依赖被显式允许：drift 表的类型转换器需要这些值类型，复制一份的代价高于方向倒置。
- 路由表离开 `core/`，[docs/subsystems/core.md](../../../../docs/subsystems/core.md) 不再登记 `appRouterProvider`。
