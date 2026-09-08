# Agent Notes：决策护栏语料

> 借鉴 deepseek-harness 的 Agent Notes 机制，适配为本仓库的单语中文版。
> 定位：记录**约束未来变更的决策护栏**——简化提案、已实现决策的边界规则、被拒但诱人的方案护栏。

## 与既有记录的分工

| 载体 | 记什么 | 生命周期 |
|---|---|---|
| `docs/adr/` | 难逆转的架构决策（三条件缺一不写，规范 §6） | 追加，可被新 ADR 取代 |
| `docs/TECH_DEBT.md` | 已知欠账清单（违规、待清理项） | 修复即删条 |
| `.agents/notes/`（本目录） | 简化提案与决策护栏 | 提案 → 实现 / 拒绝 → 归档密封 |

## 目录与状态

```
.agents/notes/
  proposed/     # 提案（Status: proposed）
  implemented/  # 已实现且仍约束未来变更的护栏（Status: implemented）
  rejected/     # 被拒但仍是"诱人错误"的护栏（Status: rejected）
  archived/     # 密封历史（Status + Archived: 日期）
```

- 文件名：`kebab-case-slug.md`，一个主题一个文件，中文正文。
- 标题下第一行必须是 `Status: <proposed|implemented|rejected>`。
- 提案模板见技能 `syn-find-simplifications`。

## 生命周期规则

1. **新增查取代**：新笔记若取代同主题活跃笔记，被取代者在同一 PR 归档。
2. **proposed 永不归档**：不值得推进就改判 rejected 并写明理由。
3. **implemented 归档判据**：理由 / 边界规则不再约束未来变更（决策彻底完成、约束已固化进代码与规范）→ 归档；仍约束 → 保留。
4. **rejected 删除判据**：失败提案不再是"诱人且有意义的错误"（没人会再犯）→ 删除；否则保留作护栏。
5. **归档即密封**：移入 `archived/`、`Status:` 下加 `Archived: YYYY-MM-DD`、不改正文；此后永不编辑、移动、删除。
6. 归档前先查取代关系：同主题旧提案被新方案覆盖时，两者在同一 PR 内一起归档。
