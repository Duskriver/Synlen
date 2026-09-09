# Agent Note: 支持范围、隐私披露与发布故障响应

Status: implemented

## Problem

评审把"经营与合规上下文偏弱"列为长期风险：产品边界散落在各处（加密 EPUB 被拒、音视频忽略、无云同步、备份明文），只能从代码和子系统页拼出来；用户文本会发往 DeepSeek 与阿里云，但没有正式的隐私披露；发布出错后没有书面止血步骤（`version.json` 是客户端唯一更新入口，改错只能人工修）；技术债散在各子系统"已知限制"里，没有统一入口。

## Decision

- **`docs/user/scope.md`**：以支持 / 不支持 / 已知边界三张表给出产品契约，用户可读；每条边界都对应实现（DRM 拒绝、音视频返回空、单层分组、明文备份）。
- **`docs/user/privacy.md`**：按"留在设备 / 离开设备"两张表列出数据流向：点词发单词 + 句子上下文给 DeepSeek、句子分析发原句、TTS 发文本与音色给阿里云、单词发音查 `dictionaryapi.dev`、更新检查只读 OSS 清单；明确无账户、无遥测、无崩溃上报，备份为明文 ZIP 且不含密钥。
- **`docs/cookbook/handling-a-release-incident.md`**：止血以 `version.json` 为先（回退需事先保留上一版副本），其次处理 GitHub Release；已安装问题版本的设备只能靠更高版本号覆盖修复。
- **技术债不建 docs 页**：工作项的唯一来源是 GitHub issues（状态、负责人、查询都在那里），`docs/development.md` 的维护表指向 `gh issue list`；子系统页继续保留运行时已知限制。这条是对[文档分层](2026-09-09-layered-docs-system.md)里"放弃扁平 TECH_DEBT 文件"的延续，已在该笔记中显式记录。
- 三份新文档按 `tool/doc-budgets.json` 设预算（55 / 50 / 45 行），并挂进 `docs/user/index.md` 与 `docs/cookbook/README.md` 的索引。

## Alternatives considered

**建 `docs/tech-debt.md` 登记表** —— 放弃：与[文档分层决策](2026-09-09-layered-docs-system.md)直接冲突。登记表把状态抄进文档，状态必然腐烂（旧 TECH_DEBT.md 就是这么坏的）；issues 有原生状态与负责人，docs 只留指向。

**把范围与隐私写进 `docs/user/index.md`** —— 放弃：index 是导航页，塞进两张边界表会让它既当目录又当契约；单独成页可各自设预算。

**隐私披露只写进 README** —— 放弃：README 面向开发者与访客，用户指南才是用户会读的地方。

## Consequences

- 用户问"为什么打不开这本书""我的数据去哪了"时有单一出处。
- 发布事故有了书面止血顺序；但 `version.json` 的回退依赖"发版时保留上一版副本"这一人工习惯，尚未自动化。
- 债务入口统一到 issues 后，`docs/` 不再承担待办清单；新增债务开 issue 并在 `development.md` 维护表可见。
