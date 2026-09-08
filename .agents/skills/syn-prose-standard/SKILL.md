---
name: syn-prose-standard
description: 在 Synlen 写或审中文文字时使用——代码注释、dartdoc、docs/、Agent Note、l10n 文案、commit message。识别必须保留的契约、按完整命题原则精简、按位置判断必要覆盖。当用户说"精简注释 / 审文案 / 把这段写清楚"时触发。
---

# Synlen 文字标准：契约保留式编辑

**这是判断框架，不是清单**：先识别这句话承载的契约，再决定删、改还是补写；篇幅不是目标。

## 真相来源

- [docs/AGENTS.md](../../../docs/AGENTS.md) — 写作规则、slop 九类、Dev Note 归属。
- [docs/glossary.md](../../../docs/glossary.md) — 规范词与禁用别称。
- [docs/development.md](../../../docs/development.md) — 注释语言约定、l10n 流程、错误消息与日志的分工。
- [docs/design.md](../../../docs/design.md) — 接口要写清的约束（不变量、错误模式）。
- [syn-doc](../syn-doc/SKILL.md) — 放置与结构；[syn-trim-cot-leakage](../syn-trim-cot-leakage/SKILL.md) — 对话视角残留。

## 什么必须保留

义务（必须 / 禁止）、不变量、前置 / 后置条件、兼容承诺、并发与生命周期约束、失败后果。被删掉或弱化即为缺陷——精简删的是叙述、重复与状态说明，不是契约。

## 完整命题原则

编辑前把句子拆成事实条款：主体与动作、条件与时序、情态（必须 / 可以 / 绝不）、负面保证与例外、归属、失败后果。所有条款都存活时才可删冗余表述；任何一条会丢，就重写而不是删除。

不是单向删减：代码与签名说不出的契约要补写（例如为什么 `ref.onDispose` 必须与资源创建成对）。判据是读者能否只凭代码加这段文字正确使用模块而不踩坑。

## 按位置的必要覆盖

| 位置 | 保留 | 删除 |
|---|---|---|
| public API dartdoc | 用途、约束、错误模式 | 实现复述 |
| 内部 `//` 注释 | 代码说不出的约束（为何这样写） | 控制流复述、显而易见的翻译 |
| 模块头注释 | 模块边界与职责一句 | 历史说明 |
| 测试注释 | 非显然的 setup 意图 | "测什么"的自述 |
| docs/、README | 承重规则 + 链接 | 故事、状态说明、重复 |
| Agent Note | Problem / Consequences 的证据 | 修饰 |
| l10n 文案 | 完整命题（含情态与例外） | 为短砍信息 |
| commit message | 为什么 | 改了什么的流水账 |

## 排除

- 生成物（`*.g.dart`、`*.freezed.dart`、l10n 生成文件）：先改源（注解 / ARB）再重新生成。
- [.agents/notes/archived/](../../../.agents/notes/archived/)：封存冻结，不编辑。
- [docs/postmortem/](../../../docs/postmortem/README.md)：唯一允许叙事化的层级。
- commit message 与 PR 描述：变更叙事是它们的本职。

## 阻断要求

1. 承重契约条款全部存活，才算精简完成。
2. 义务、情态与例外不得被改写成陈述。
3. 假设不得升级成已发布行为。
4. 生成物不手改：改源再重新生成。
5. 用户可见文案过 l10n（`app_en.arb` 与 `app_zh.arb` 同批），不硬编码。
6. 术语用 [docs/glossary.md](../../../docs/glossary.md) 的规范词。

## 手动检查

- 读者能否只看当前 HEAD 解析全部引用；不能就转 [syn-trim-cot-leakage](../syn-trim-cot-leakage/SKILL.md)。
- 全范围检查（搜索 + 通读），不只看最大的文件。
- 每个候选分类：保留 / 补充 / 精简 / 重构 / 搁置；不为凑删减量制造编辑。
- 涉及 .dart 跑 `dart format` + `flutter analyze`；文档跑 `dart run tool/doc_gates.dart`。

## 报告发现

- 范围、明确修改、有意保留的边界情况、搁置项。
- 补写的契约与理由。

## Dev Note

None.
