# Agent Note: 文档按事实分层并交给门禁

Status: implemented

## Problem

旧文档把不同性质的事实混在少数几个大文件里：`CHANGELOG.md` 既是用户变更记录又是工程变更史，`CONTEXT.md` 是术语表，`DEVELOPMENT_STANDARDS.md` 与 `DEVELOPMENT_WORKFLOW.md` 混着规则、流程与命令，`TECH_DEBT.md` 同时承担销账记录、待办清单与实测数字，决策理由散在 `docs/adr/`。后果是同一规则出现在多个家、状态与历史叙述随代码腐烂（"已修复""未来将"），而没有任何机器校验，文档与实现的漂移只能靠人偶然发现。

## Decision

- 事实按"作者在回答什么问题"归属唯一一层，层级表同时写出"不属于此层"，反向定义防止外溢：根 `AGENTS.md` 只放 1–3 行常驻指令，`architecture.md` 是模块地图，`subsystems/` 是每模块参考，`cookbook/` 是带验证步骤的手册，`user/` 面向使用者，`glossary.md` 是术语唯一来源，`design.md` 管接口形状，`testing.md` 与 `development.md` 管贡献者日常，`postmortem/` 是唯一允许叙事化的层级，理由进 Agent Notes。
- 决策记录按 `{lifecycle}/{class}/` 分目录，`Alternatives considered` 强制，implemented 笔记不得出现提案语言。
- 规则由 `tool/doc_gates.dart` 执行：链接与锚点、仓库路径存在性、术语与代码一致、笔记格式、技能元数据、预算与 Markdown 卫生；`tool/doc-budgets.json` 给常驻文档设上限，超限顺序是搬迁 → 精简 → 抬上限。
- 文档改动与代码改动过同一道 CI 门禁（`.github/workflows/flutter_ci.yml` 的 docs job）。

## Alternatives considered

**继续用 TECH_DEBT / CHANGELOG / ADR 的扁平结构** —— 放弃：销账记录与待办同处一室，状态叙述必然腐烂，且无法机器校验。

**只写规范、不加门禁** —— 放弃：没有执行者的规则会漂移，本项目已经出现过术语与数字漂移。

**引入外部文档生成器或站点** —— 放弃：多一层构建与部署，换不来事实归属的改善。

## Consequences

- 新增事实先问"它属于哪一层"，同一条事实只留一个家，其余改链接。
- 状态叙述不再入库：变更叙事进 commit、PR 与 Agent Notes；事故进 postmortem。
- 门禁只证明结构与可核查事实，语义与可读性仍由评审负责。
