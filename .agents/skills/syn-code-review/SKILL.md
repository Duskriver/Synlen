---
name: syn-code-review
description: 在 Synlen 评审 PR 或待合并改动时使用——同时走标准轴（是否守本仓库规范）与 spec 轴（是否贴合发起 issue 的验收标准），执行阻断性检查并报告缺陷。当用户说"评审代码 / review / 看看这个改动"时触发。
---

# Synlen 代码评审

**这是判断框架，不是清单**：本技能给出必须覆盖的检查面与阻断判据，不替代读代码本身。优先看正确性、资源生命周期与必要行为的中断；风格交给 `flutter analyze` 与 `dart format`。

## 真相来源

- [AGENTS.md](../../../AGENTS.md) — 常驻指令。
- [docs/architecture.md](../../../docs/architecture.md) — 分层、模块边界、跨 feature 依赖的允许形态。
- [docs/design.md](../../../docs/design.md) — 深模块、删除测试、seam 纪律。
- [docs/development.md](../../../docs/development.md) — Riverpod、错误处理、资源生命周期、日志、l10n、提交门禁。
- [docs/testing.md](../../../docs/testing.md) — 测试分层与最小证据。
- [docs/glossary.md](../../../docs/glossary.md) — 规范词与禁用别称。
- [docs/subsystems/README.md](../../../docs/subsystems/README.md) — 每模块语义、边界与已知限制。
- [.agents/notes/README.md](../../../.agents/notes/README.md) — 决策记录与理由。

## 双轴

先确认评审对象：`gh pr view <n> --json baseRefName,headRefName` 或 `git merge-base`；目标分支变更后重新评审。看全量 diff（`gh pr diff <n>` 或 `git diff <base>...HEAD`），先 `--stat` 判范围再逐文件读足上下文。读发起 issue（`gh issue view <n>`）记住验收标准。

- **标准轴**：改动是否守本仓库文档化的规范（下面两节）。
- **spec 轴**：改动是否贴合 issue 的验收标准；偏离要指出是缺口还是超范围。

两轴分别报告，不合并成一条结论。

## 阻断要求

1. **l10n**：新增用户可见文案走 ARB（`app_en.arb` 与 `app_zh.arb` 同批），UI 不硬编码。
2. **文档同步**：受影响的架构、子系统页、术语表、流程与测试策略在同一 diff 更新。
3. **术语**：核心类型与领域概念用 [docs/glossary.md](../../../docs/glossary.md) 的规范词，禁用别称清零；概念变更同步术语表。
4. **资源生命周期**：新增 provider / 协调器 / 流订阅必须有对应释放（`ref.onDispose` 与资源创建成对，重复进入不泄漏）。
5. **语义测试**：断言行为与边界，不是"对象存在 / 不抛异常"；domain、application、parser、import 的改动无测试不合并。
6. **门禁**：`flutter analyze` 零 error 零 warning、`dart format`、按最小证据跑测试、codegen 产物与注解一致、文档改动过 `dart run tool/doc_gates.dart`。

## 手动检查

下面每条若由本次改动新增，同样是阻断项。

- **分层**：`presentation → application → domain`、`data → domain`；新增的 `presentation → data`、`domain → 上层`、feature 间互引直接阻断；进 `core/` 的必须被 ≥2 个 feature 使用。
- **Riverpod**：`AsyncValue` 三态齐全、无裸 `.value`；依赖经 provider 注入，不在内部 `new`；实现与 provider 文件分离。
- **错误处理**：捕获点在 application，异常转状态字段；用户可读消息走 l10n，内部细节只入日志。
- **并发与生命周期**：流订阅取消、一页一实例的协调器、平台通道回调的泄漏路径。
- **测试强度**：在 seam 处用 fake 替换，不依赖真实网络 / 文件系统 / 平台通道。
- **增量纪律**：重构与功能分开提交；新代码按规范，旧代码路过即修（[决策](../../../.agents/notes/implemented/architecture/2026-08-10-incremental-refactor-over-big-bang.md)）。
- **体量**：单文件超过 ~400 行先找拆分点（[体量规则](../../../docs/design.md#体量)）；接口能再小就再小。

## 报告发现

- 每条发现给：缺陷、位置（`文件:行`）、影响、证据。
- 区分阻断项与建议项；绿色门禁已覆盖的问题不报。
- 与既有 Agent Note 冲突的改动显式指出并说明是否值得重开，不默默放过。

## Dev Note

None.
