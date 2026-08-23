---
name: syn-find-simplifications
description: 在 Synlen 寻找非显而易见的简化候选并写成 Agent Note 提案时使用。识别 dead / duplicated / speculative / over-built 代码，用调用方证据证明或否决每个候选。当用户要求"找简化机会 / 代码瘦身 / 砍掉没用的东西"或审计被取代的笔记时触发。
---

# Synlen 简化机会挖掘

> guidance, not a checklist：跟随代码、保持判断；宁要少而扎实的提案，不要一堆薄弱猜测。

## 1. 先建上下文

- 读 `AGENTS.md`、`docs/DEVELOPMENT_STANDARDS.md`、`docs/TECH_DEBT.md`（已有欠账不重复提案）、`docs/adr/`。
- **有意设计不算债**：Isar→drift 双持久化并存是 ADR-0002 的迁移期决策、Rust FFI 是性能决策——轻率提议删除会被否决；提改动先读对应 ADR。

## 2. 识别强候选

按信号找，不按目录扫：

- **dead**：无 `lib/` 生产调用方的 public 方法 / 组件 / provider / l10n 键。
- **duplicated**：镜像同一事实的重复表示（同一状态既存 provider 又存字段；`reader/application` 的 SharedPreferences get/set 透传即此类信号，见 TECH_DEBT #4）。
- **speculative**：为假想需求做的泛化——没人用的参数、只有一种实现的"扩展点"（假 seam，规范 §3）。
- **over-built**：仅为保护未用 API 而存在的测试；可用依赖 / 语言内置替代的手写代码。

## 3. 证明或否决

- `rg` 区分调用方：`lib/` 内命中 = 生产调用；仅 `test/`、`docs/` 命中 ≠ 生产调用。
- 读实际调用点确认语义，不只看名字。
- **否决**：有生产调用；已有 ADR / TECH_DEBT 条目覆盖；改动太小不值得提案——记入 `docs/TECH_DEBT.md` 对应区块，或按 Boy Scout Rule 顺手修（TODO 不散落代码注释，规范 §10）。

## 4. 写 Agent Note 提案

按 `.agents/notes/README.md` 契约，在 `.agents/notes/proposed/` 创建，结构固定：

```
# <一句话标题>
Status: proposed

## Problem
（现状证据：调用方统计、行数、维护负担）
## Proposal
（删什么 / 合并什么，改动边界）
## Why not keep it
（保留的真实成本 vs 删除的风险）
## Acceptance criteria
（怎样算完成：调用方清零、测试调整、文档同步）
## Risks
（误删风险、迁移顺序）
```

- 每条新笔记检查是否**取代**既有活跃笔记（同主题旧提案被新方案覆盖 → 同一 PR 归档旧笔记，见 `syn-archive-agent-notes`）。

## 5. 验证与报告

- 纯笔记：`git diff --check`；涉及代码：`flutter analyze` + 相关测试。
- PR 报告：新增 / 合并 / 删除的笔记数量、调查范围（哪些目录、哪些信号）、有意排除项及理由、通过的检查。
