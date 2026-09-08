---
name: syn-trim-cot-leakage
description: 清理 Synlen 仓库里"读起来像聊天记录"的文字（注释、dartdoc、docs/、Agent Note）——写作会话残留、PR 叙事、评审辩解等八类。当审计文字发现引用对话位置、PR 视角或未落地延期时触发，配合 syn-prose-standard 使用。
---

# 清理会话视角泄漏

**这是判断框架，不是清单**：逐段问一个问题，而不是套用删词表。

## 真相来源

- [syn-prose-standard](../syn-prose-standard/SKILL.md) — 契约保留与句子级编辑。
- [docs/AGENTS.md](../../../docs/AGENTS.md) — 写作规则与 slop 九类。
- [.agents/notes/README.md](../../../.agents/notes/README.md) — 笔记的生命周期与取代规则。
- [docs/subsystems/README.md](../../../docs/subsystems/README.md) — 已知限制与待办的新家。

## 判定标准

对每段可疑文字问：**一个只看当前 HEAD、接触不到任何对话记录、PR 讨论、issue 评论的读者，能否解析所有引用、验证所有断言？**

- 能 → 合规；啰嗦交给 [syn-prose-standard](../syn-prose-standard/SKILL.md)。
- 不能但含事实 → 改写成站在仓库视角的现在时自足表述，删掉对话痕迹。
- 不能且无事实 → 整段删除。

## 八类泄漏

1. 失效的会话引用（"上面说过"、"如前所述"、指向对话位置的编号）。
2. PR / 分支视角（"本 PR 新增"、"此分支改动了"）。
3. 变更叙事与版本戳（"以前是"、"不再是"、"这一版"）——commit message 与复盘除外。
4. 评审编排（"评审中被否决"、"按 review 意见改为"）。
5. 向评审者辩解（"这样写是因为评审要求"）。
6. 控制流 / 推导过程复述（"先查 A 再查 B 所以…"）。
7. 犹豫措辞与无主延期（"也许以后"、"暂时先这样"而无去向）——有去向的记进子系统页的「已知限制与待办」或 `.agents/notes/proposed/`。
8. 未完成翻译的残片、无意义的中英混杂。

## 不可误删

issue / Agent Note 引用、`// ignore:` 的抑制理由、回归锚定（"防止 #3 复发"）、实测边界数据、状态机新旧状态切换的描述、外部标准引用。

## 阻断要求

1. 删之前先枚举该段的命题，核对「不可误删」清单。
2. 义务不得改成陈述，假设不得升级成已发布行为。
3. 生成物先改源（注解 / ARB）再重新生成。
4. 有去向的延期改成链接，不留在原地。

## 手动检查

- 范围显式声明；排除生成物、`.agents/notes/archived/`、[docs/postmortem/](../../../docs/postmortem/README.md)、commit message。
- 只读审计：`rg` 搜常见模式（`本 PR`、`以前是`、`不再是`、`评审`、`如前所述`、`暂时`），再通读散文最密的段落。
- 重跑搜索确认只剩合规保留项。

## 报告发现

- 范围、八类各自命中的处数、改写与删除各做了什么、有意保留项。
- `git diff --check`；涉及 .dart 跑 `dart format` + `flutter analyze`。

## Dev Note

None.
