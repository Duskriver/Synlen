# Synlen 开发流程

> 本文件定义**开发工作流**：什么阶段用哪个 Skill、产出什么、如何衔接。
> 与 `DEVELOPMENT_STANDARDS.md`（怎么写代码）互补——本文件管"走的流程"，标准管"写出来的样貌"。
> 配套：`AGENTS.md`（入口）、`docs/agents/`（工程技能配置）、`CONTEXT.md` + `docs/adr/`（领域语言与决策）。

## 0. 流程原则

- **按任务规模适配**（见 §7）：小改动直达实现，大改动才走完整流水线，不强制每一步。
- **硬性底线不可破**（见 §6）：无论多小的改动都受约束。
- **每个 Skill 的输出是下一个的输入**，串起来成流水线；产出物都落到 issue tracker / docs，不留散装对话。

## 1. 想法（Ideas）

**进入信号**：一个新点子、功能诉求、模糊的改进。

| 场景 | 用 Skill | 产出 |
|---|---|---|
| 想法需要打磨、压力测试 | `grilling` / `grill-me` / `batch-grill-me` | 清晰的需求描述；决策成熟的方案 |
| 想法太模糊、需要别人（或未来的自己）补信息 | `to-questionnaire` | 一份问卷发出去 |
| 涉及新术语/概念模糊 | `domain-modeling` / `ubiquitous-language` | `CONTEXT.md` 词汇落定 |
| 只想记录想法暂不推进 | 直接建 issue（`gh issue create`）走 `triage` | 待 triage 的 issue |

**出口**：需求描述清晰、术语无歧义、判断这是一条值得做的工作。

## 2. 规格（Spec）

**进入信号**：想法打磨完毕，需要把"怎么做"固定成文字。

| 场景 | 用 Skill | 产出 |
|---|---|---|
| 常规功能 | `to-spec` | spec 发布为 GitHub issue（正文即规格） |
| 大块工作（超过一个 session 的量） | `wayfinder` | 决策票地图（`wayfinder:map` issue + 子 ticket） |
| 重构 | `request-refactor-plan` | 重构 RFC + 小步提交计划，建 issue |
| 架构决策（难逆转/会困惑/有取舍三条件） | `domain-modeling` | `docs/adr/NNNN-*.md` |
| 新模块/接口要多个方案对比 | `design-an-interface` / `codebase-design` | 接口设计选择 |

**出口**：规格有 owner、有验收标准、技术路径明确。

## 3. 拆票（Tickets）

**进入信号**：有机票可拆的规格（通常 ≥ 中等规模）。

| 场景 | 用 Skill | 产出 |
|---|---|---|
| 规格拆成可执行 ticket | `to-tickets` | ticket 列表，每个声明阻塞边界与上下文 |
| 新 issue 进入工作队列 | `triage` | 打五标签之一：`needs-triage` / `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix` |

**出口**：每张 ticket 是 `ready-for-agent` 或 `ready-for-human`，有明确边界可独立完成。

## 4. 实现（Implement）

**进入信号**：有一张 `ready-for-agent`（交给 AI）或 `ready-for-human` 的 ticket。

| 场景 | 用 Skill / 流程 | 产出 |
|---|---|---|
| 按 ticket 实现 | `implement` | 代码 + 测试 |
| 复杂逻辑/算法 | `tdd` | 红-绿-重构的测试驱动代码 |
| 新模块设计 | `codebase-design`（深模块原则） | 小接口大实现的模块 |
| 拿不准交互是否合理 | `prototype` | 可抛弃的验证原型 |
| 推送前验证 | `syn-pre-push-checks` | 按变更类型选择的最小测试证据 + 推送门禁 |
| 提交 | 规范 §9 | 一个逻辑一个 commit，含 `type(scope): 中文描述` |

**出口**：`flutter analyze` 零告警、`dart format` 已跑、`syn-pre-push-checks` 的最小证据通过；**全量 `flutter test` 在推送 / PR 合并前必须全绿**。

## 5. 评审（Review）

**进入信号**：功能实现完成，准备合并。

| 场景 | 用 Skill | 产出 |
|---|---|---|
| 改动评审 | `code-review` + `syn-code-review` | 双轴结论：**标准**（syn 版含 Flutter 分层与六项阻断清单） + **spec**（是否贴合原需求） |
| 用户可见 UI 行为变更 | `syn-record-ui-demo` | 真实运行的演示 GIF，嵌入 PR 正文 |
| 合并堆叠式 PR | `syn-merging-stacked-prs` | 经 GitHub 原生 stack 的整体 / 部分落地 |
| 评审不通过 | 回到 §4 修复 | 修复后的重新评审 |

**出口**：两条轴都通过 → 合并。

## 6. 维护（Maintain）

持续进行的活动，不限于某个阶段：

| 场景 | 用 Skill | 产出 |
|---|---|---|
| 用户对话式报 bug | `qa` | 建档的 GitHub issue，进 `triage` |
| 疑难 bug / 性能回归 | `diagnosing-bugs` | 定位 + 根因 + 修复建议 |
| 定期架构体检 | `improve-codebase-architecture` | 深化机会 HTML 报告，挑选后 `grill` |
| git 高危操作防护（可选） | `git-guardrails-claude-code` | 阻止危险命令的 hooks |
| 简化机会挖掘 | `syn-find-simplifications` | Agent Note 提案（`.agents/notes/proposed/`） |
| Agent Notes 治理 | `syn-archive-agent-notes` | 归档 / 密封后的决策语料 |
| 文档结构与审计 | `syn-doc-standards` | 层级合理、无冗余的 docs/ |
| 文字精简与审查 | `syn-prose-standard` | 契约保留的注释 / 文案 / 文档 |
| 会话泄漏清理 | `syn-trim-cot-leakage` | 仓库视角自足的文字 |

## 7. Skill 速查表

| Skill | 阶段 | 用途 |
|---|---|---|
| `grilling` / `grill-me` / `batch-grill-me` | 1 | 面试式打磨想法/方案 |
| `to-questionnaire` | 1 | 无法回答的决策转问卷 |
| `domain-modeling` / `ubiquitous-language` | 1/2 | 术语、统一语言、ADR |
| `wayfinder` | 2 | 超大工作拆决策票地图 |
| `to-spec` | 2 | 对话 → spec 发布 issue |
| `request-refactor-plan` | 2 | 重构计划 + 小步提交 |
| `codebase-design` / `design-an-interface` | 2/4 | 模块与接口设计 |
| `to-tickets` | 3 | spec → 带阻塞边 ticket 列表 |
| `triage` | 3/6 | issue 分类路由 |
| `implement` | 4 | 按 ticket 实现 |
| `tdd` | 4 | 测试驱动实现 |
| `prototype` | 4 | 可弃原型验证 |
| `code-review` | 5 | 标准 + spec 双轴评审 |
| `qa` | 6 | 对话式 bug 建档 |
| `diagnosing-bugs` | 6 | 疑难 bug 诊断 |
| `improve-codebase-architecture` | 6 | 架构审计 |
| `setup-matt-pocock-skills` | 基建 | 一次性仓库配置（已完成） |
| `syn-pre-push-checks` | 4 | 推送前最小证据选择与门禁 |
| `syn-code-review` | 5 | 仓库规范面评审（分层 / Riverpod / 阻断清单） |
| `syn-record-ui-demo` | 5 | UI 行为变更演示 GIF |
| `syn-merging-stacked-prs` | 5 | 堆叠 PR 原生合并 |
| `syn-find-simplifications` | 6 | 简化机会 → Agent Note 提案 |
| `syn-archive-agent-notes` | 6 | 决策笔记生命周期 |
| `syn-doc-standards` | 6 | 文档放置与语料审计 |
| `syn-prose-standard` | 6 | 契约保留式文字编辑 |
| `syn-trim-cot-leakage` | 6 | 清理会话视角泄漏 |

本仓库用不到的 Skill 不在列（writing-*、文档处理、TS 专属、教学等）。`syn-*` 系借鉴自 deepseek-harness 的 DSH 范式，映射见 `docs/agents/skills.md`。

## 8. 硬性底线（所有改动都受约束，规范 §6/8/9）

1. **实现前必须有 ticket**（哪怕只有一句话的 issue），杜绝无主开发。
2. **提交前必过**：`flutter analyze`（零 error 零 warning）+ `dart format` + 最小测试证据（`syn-pre-push-checks`）；推送 / 合并前全量 `flutter test` 必须全绿。
3. **新功能/核心逻辑必须带测试**；测试不过不合并。
4. **重构与功能分开提交**；重构走 ADR-0001 增量纪律（路过即修）。
5. **注释与文档用中文**；标识符、命令、标签保持英文（规范 §8.1）。

## 9. 规模适配表

| 规模 | 例子 | 走的步骤 |
|---|---|---|
| 小改动 | 修一个 bug、改一个文案、调一个参数 | 直接 §4 实现 → §5 评审（可省 code-review）→ 提交 |
| 中功能 | 新增一个页面/能力 | §1（简）→ §2 to-spec → §4 → §5 → 提交 |
| 大功能/重构 | 阅读器引擎改造、新增整个模块 | 完整流水线 §1→§6，必要时 wayfinder/tickets |

判断标准：改动是否涉及**跨层架构**、**超过 3 个文件**、**影响数据模型**——是则至少走 §2。
