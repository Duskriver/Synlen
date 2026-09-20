# 子系统参考

本目录是词镜各模块的参考页：每页 owns 一个模块的类型、语义与边界，用于查类型、确认边界，不叙述行为流程；模块划分与依赖方向见[架构地图](../architecture.md#模块)，术语定义见[术语表](../glossary.md)，测试分层见[测试](../testing.md)，每页以 `## Dev Note` 结尾。

| 页面 | owns |
|---|---|
| [core.md](core.md) | 跨模块共享能力：drift 数据库与 schema、路由、全局主题、存储路径、日志与 toast、provider、通用 widget、文件选择与导入缓存、外链启动、应用信息 |
| [library.md](library.md) | 藏书：导入与解析、书架与分组、排序、备份与恢复、详情页，以及 `BookQueries` / `BookActions` / `BookshelfNotifier` |
| [reader.md](reader.md) | 阅读：出版物供给、Readium 会话、完整 Locator、学习触摸、主题和原生交互 |
| [learning.md](learning.md) | 学习：点词释义与长句分析、TTS 发音、学习缓存表与按音色缓存、`LearningAudioCoordinator`、`LearningEntry`、错误码到 l10n 的映射 |
| [settings.md](settings.md) | 设置组合面：全局主题、自定义字体、AI 密钥、TTS 音色、缓存清理、备份导出、更新检查 |
| [rust.md](rust.md) | `rust/`：EPUB 中央目录缓存与解压（`readEpubFile`）、flutter_rust_bridge 绑定与 codegen |

## Dev Note

None.
