---
name: syn-find-simplifications
description: 在 Synlen 找非显而易见的简化候选并写成 Agent Note 提案时使用——识别 dead / duplicated / speculative / over-built 信号，用调用方证据证明或否决每个候选，并做取代检查。当用户说"找简化机会 / 代码瘦身 / 砍掉没用的东西"时触发。
---

# 简化机会挖掘

**这是判断框架，不是清单**：跟着代码走，宁可少而扎实的提案，不要一堆薄弱猜测。有意设计不算债——先读它的 Agent Note。

## 真相来源

- [.agents/notes/README.md](../../../.agents/notes/README.md) — 笔记的生命周期、类别、必填小节与取代规则。
- [docs/design.md](../../../docs/design.md) — 深模块、删除测试、seam 纪律。
- [docs/architecture.md](../../../docs/architecture.md) — 模块边界与跨 feature 依赖的允许形态。
- [docs/subsystems/README.md](../../../docs/subsystems/README.md) — 每模块的「已知限制与待办」，已有条目不重复提案。
- [AGENTS.md](../../../AGENTS.md) — 增量重构与 Boy Scout Rule。

## 四个信号

- **dead**：`lib/` 里没有生产调用方的 public 方法 / 组件 / provider / l10n 键。
- **duplicated**：同一事实的两个表示——同一状态既存 provider 又存字段；repository 方法只是把 `sharedPreferencesProvider` 的 get / set 原样转发。
- **speculative**：为假想需求做的泛化——没人用的参数、只有一种实现的"扩展点"（假 seam）。
- **over-built**：只为保护未用 API 存在的测试；能用依赖或语言内置替代的手写代码。

## 证明或否决

- `rg` 区分调用方：`lib/` 命中是生产调用；只命中 `test/` 或 `docs/` 不算。
- 读实际调用点确认语义，不只看名字。
- **否决**：有生产调用；已被 Agent Note 或子系统页的待办覆盖；改动太小不值得提案——按 Boy Scout Rule 顺手修，或记进子系统页的「已知限制与待办」。
- 有意设计先读它的 Agent Note 再判断：性能与兼容决策、迁移期并存形态，轻率提议删除会被否决。

## 写 Agent Note 提案

模板位置与必填小节见 [.agents/notes/README.md](../../../.agents/notes/README.md) 与 [agent-note 骨架](../syn-doc/templates/agent-note.md)；提案落在 `.agents/notes/proposed/` 的 simplification 类别下。现状证据要能独立成立：调用方统计、行数、维护成本。

## 取代检查

新增笔记前搜活跃树，看是否已有覆盖同一决策或机制的旧笔记。完全取代 → 同一次改动归档旧笔记；部分取代 → 保持活跃并交叉链接。归档规则见 [.agents/notes/README.md](../../../.agents/notes/README.md)。

## 阻断要求

1. 每个候选都有 `rg` 证据，或明确的否决理由。
2. 不重复已有待办与 Agent Note 覆盖的问题。
3. 提案按 proposed 骨架写，含 `## Alternatives considered`。
4. 新笔记必须做取代检查，取代关系在同一次改动里落地。

## 手动检查

- 调查范围（哪些目录、哪些信号）、有意排除项及理由。
- 纯笔记改动跑 `git diff --check`；涉及代码跑 `flutter analyze` + 相关测试。

## 报告发现

- 新增 / 合并 / 归档的笔记数量与路径。
- 每个候选的判定：采纳 / 否决 + 证据。
- 排除范围与理由、通过的检查。

## Dev Note

None.
