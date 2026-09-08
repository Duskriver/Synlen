# 操作手册

本目录是带编号验证步骤的操作手册：每篇覆盖一类改动的完整流程，从动手改到确认生效。设计理由写在 [Agent Notes](../../.agents/notes/README.md)，类型与模块语义写在 [子系统参考页](../subsystems/README.md)，本目录只写步骤。

## 手册

| 手册 | owns |
|---|---|
| [adding-a-feature](adding-a-feature.md) | 新增 feature 模块：四层骨架、provider 暴露、`AsyncValue` 三态、错误落点、测试与文档同步 |
| [adding-an-l10n-string](adding-an-l10n-string.md) | 用户可见文案：ARB 同批更新、占位符、重新生成、错误码到文案的映射 |
| [changing-reader-web-assets](changing-reader-web-assets.md) | 阅读器 TypeScript/CSS：源与生成物、学习文本提取规则、浏览器回归测试 |
| [changing-the-database-schema](changing-the-database-schema.md) | drift schema：加表、加列、改列、`schemaVersion` 与迁移测试 |

每篇正文都以编号的 `## 验证` 步骤收束，按顺序执行即可确认改动生效；`## Dev Note` 是作者的非权威补充。

## 不属于本层

判断改动该走哪篇手册时，先看 [文档标准](../AGENTS.md) 的层级表：分层与模块边界归 [architecture.md](../architecture.md)，接口形状归 [design.md](../design.md)，测试分层归 [testing.md](../testing.md)，日常命令归 [development.md](../development.md)。

## Dev Note

None.
