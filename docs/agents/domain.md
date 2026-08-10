# 领域文档

工程技能在探索代码库时应如何消费本仓库的领域文档。

## 探索前先读这些

- 根目录的 **`CONTEXT.md`**，或
- 根目录的 **`CONTEXT-MAP.md`**（若存在）——它指向每个上下文各自的 `CONTEXT.md`。读取与当前主题相关的每一份。
- **`docs/adr/`**——读取与即将工作的区域相关的 ADR。多上下文仓库中，还要检查 `src/<context>/docs/adr/` 下的上下文级决策。

以上文件若不存在，**静默跳过**。不要指出缺失，也不要建议预先创建。`/domain-modeling` 技能（通过 `/grill-with-docs` 与 `/improve-codebase-architecture` 触达）会在术语或决策真正落定时按需创建它们。

## 文件结构

单上下文仓库（大多数仓库）：

```
/
├── CONTEXT.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

多上下文仓库（根目录存在 `CONTEXT-MAP.md`）：

```
/
├── CONTEXT-MAP.md
├── docs/adr/                          ← 系统级决策
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/                  ← 上下文级决策
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

## 使用词汇表的术语

输出中命名领域概念时（issue 标题、重构提案、假设、测试名），使用 `CONTEXT.md` 定义的术语。不要漂移到词汇表明确 Avoid 的同义词。

如果需要的概念不在词汇表里，那是一个信号——要么你在发明项目没在用的语言（重新考虑），要么词汇表真有缺口（记下来交给 `/domain-modeling`）。

## 标记 ADR 冲突

如果你的输出与现有 ADR 矛盾，显式指出来，而不是默默覆盖：

> _与 ADR-0007（事件溯源订单）矛盾——但值得重开，因为……_
