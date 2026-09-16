# 操作手册

本目录是带编号验证步骤的操作手册：每篇覆盖一类改动的完整流程，从动手改到确认生效。设计理由写在 [Agent Notes](../../.agents/notes/README.md)，类型与模块语义写在 [子系统参考页](../subsystems/README.md)，本目录只写步骤。

## 手册

| 手册 | owns |
|---|---|
| [adding-a-feature](adding-a-feature.md) | 新增 feature 模块：四层骨架、provider 暴露、`AsyncValue` 三态、错误落点、测试与文档同步 |
| [adding-an-l10n-string](adding-an-l10n-string.md) | 用户可见文案：ARB 同批更新、占位符、重新生成、错误码到文案的映射 |
| [changing-reader-web-assets](changing-reader-web-assets.md) | 阅读器 TypeScript/CSS：源与生成物、学习文本提取规则、浏览器回归测试 |
| [changing-the-database-schema](changing-the-database-schema.md) | drift schema：加表、加列、改列、`schemaVersion` 与迁移测试 |
| [publishing-a-release](publishing-a-release.md) | 发版：版本号与 versionCode 派生、release notes 段改名、tag 构建、Gitee 发布与验证 |
| [handling-a-release-incident](handling-a-release-incident.md) | 发布后出问题：判定影响面、回退 `version.json`、处理 Release、发修复版本 |
| [measuring-performance](measuring-performance.md) | 性能基线：设备矩阵、冷启动 / 导入 / 翻章 / 内存的测量方法与记录格式 |

每篇正文都以编号的 `## 验证` 步骤收束，按顺序执行即可确认改动生效；`## Dev Note` 是作者的非权威补充。

## 不属于本层

判断改动该走哪篇手册时，先看 [文档标准](../AGENTS.md) 的层级表：分层与模块边界归 [architecture.md](../architecture.md)，接口形状归 [design.md](../design.md)，测试分层归 [testing.md](../testing.md)，日常命令归 [development.md](../development.md)。

## Dev Note

None.
