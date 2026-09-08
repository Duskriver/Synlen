# 架构

词镜是一个离线优先的 Flutter 阅读器：书籍、进度与学习缓存都存在设备上，只有点词释义、句子分析与 TTS 需要网络（DeepSeek / 阿里云 TTS，密钥由用户自填）。本文件是有序地图：先读分层与模块边界，需要类型和模块内部语义时进 [subsystems/](subsystems/README.md)。

## 分层

Feature-first + 四层，依赖单向流动：

```
presentation → application → domain
      ↓              ↓
      └──── data ←──┘     data 提供仓库、服务与 store 实现，读取 domain 模型
```

```
lib/src/
  features/
    library/ reader/ learning/ settings/
      presentation/  ← Widget、Screen
      application/   ← Controller、Coordinator、装配入口
      domain/        ← 实体、枚举、异常、纯逻辑
      data/          ← Repository、Service、Parser
  core/              ← 跨模块共享：database、theme、storage、services、providers、widgets、file_handling、config、url_launcher
  app_router.dart    ← 路由表（应用外壳，唯一允许依赖各 feature presentation 的位置）
  rust/              ← 性能敏感逻辑（FFI，经 core 暴露）
```

规则：

- **依赖方向**：`presentation → application → domain`、`data → domain`；`application` 可以依赖本 feature `data` 的 provider 与实现。禁止 `presentation → data`（presentation 只 `ref.watch` provider）；禁止 `domain` 依赖上层。
- **接口归属**：跨 feature 暴露的接口与实现都在 `application`（`BookQueries` / `RepositoryBookQueries`）；feature 内部的 seam 接口就近定义（如 `data/stores/` 的 `WordCacheStore`）。
- **feature 之间不互相 import**；跨 feature 只经对方 `application` 暴露的接口，见 [跨 feature 依赖](#跨-feature-依赖)。
- **`core/` 是共享工具箱**：放进去的东西必须被 ≥2 个 feature 使用，否则留在所属 feature。
- **`domain` 是纯 Dart**：不 import Riverpod，不触碰 data / presentation。UI 类型（如 `Color`）仅在无法避免时允许（参考 `ReaderSettings` 引入 `AppThemeSettings` 的做法）。

写新模块前读 [design.md](design.md)：深模块、删除测试与 seam 纪律。

## 模块

| 模块 | 职责 | 入口 |
|---|---|---|
| [library](subsystems/library.md) | 藏书：导入（EPUB / TXT）、书架、分组、排序、备份恢复、详情 | `BookQueries`、`BookActions`、`BookshelfNotifier` |
| [reader](subsystems/reader.md) | 阅读：内容供给、分页、章节与页码导航、脚注、图片、主题 | `ReaderSessionFactory`、`BookSession` |
| [learning](subsystems/learning.md) | 学习：点词释义、长句分析、TTS 发音与缓存 | `LearningEntry` |
| [settings](subsystems/settings.md) | 设置：主题、字体、AI 密钥、音色、缓存清理、备份导出、更新检查 | 组合面（唯一允许跨 feature 编排的模块） |
| [core](subsystems/core.md) | 跨模块能力：数据库、路由、主题、存储、日志、导入编排、文件处理 | provider 与 service |
| [rust](subsystems/rust.md) | EPUB 中央目录缓存与解压（FFI） | `readEpubFile` |

## 数据流

```
文件选择（原生 SAF / 分享）→ UnifiedImportService
  → EPUB：EpubZipParser + EpubImportService（压缩存盘）
  → TXT ：解码（BOM → UTF-8 → GBK）→ 归一化为 UTF-8 → 虚拟章节
  → ShelfBook + BookManifest 落库（drift）
阅读：ReaderScreen → ReaderSessionFactory → BookSession → 内容供给（epub:// 虚拟域 / TXT 章节）
      进度：ReadingProgressController → 防抖落库 ShelfBook.progress
学习：点词 / 长按 → LearningEntry → WordLearningController / SentenceLearningController
      → DeepSeek（释义、分析）+ 阿里云 TTS（发音）→ 缓存表（按音色区分）
```

## 跨 feature 依赖

允许的形态只有三种：**组合面**（`settings`）经其他 feature 的 `application` 编排；**宿主调能力模块**（`reader` 经 `LearningEntry`）；**值类型与配置读取**（`domain` 类型、`settings/application` 的配置）。

不允许的形态：任何 feature 的 `presentation` 直接依赖其他 feature 的 `data`；`application` 直连其他 feature 的 `data`。`core/` 只能依赖 feature 的 `domain` 值类型（drift 表的类型转换器），不得依赖 feature 的其余层。

新增跨 feature 边之前先读 [组合面决策](../.agents/notes/implemented/architecture/2026-09-08-composition-surface-cross-feature.md)。边与违规由门禁核对，不靠人眼：

```sh
dart run tool/layer_gates.dart --list   # 当前跨 feature 边与 core -> feature 边
dart run tool/layer_gates.dart          # 违规检查；CI 与提交前都跑
```

## 新行为放哪

| 要加的东西 | 落点 |
|---|---|
| 新的书籍格式 | `library/data/parsers/` 新增 parser + `BookFormat` 分支；导入与内容供给两处都要覆盖 |
| 新的阅读能力（手势、排版、导航） | `reader/application/` 的编排 + `reader/presentation/` 的 UI；跨层逻辑先落 application |
| 新的学习能力（新的 AI 任务） | `learning/application/` 的 controller + `learning/data/` 的 service；缓存策略跟着缓存表走 |
| 新的设置项 | `settings/` 三件套：domain 值对象、application notifier、presentation 卡片 |
| 跨 feature 的能力 | 先问是否真的被 ≥2 个 feature 使用；是则 `core/`，否则留在所属 feature |
| 性能敏感的解析 / 解压 | `rust/src/api/` + 重跑 flutter_rust_bridge codegen |

## Dev Note

None.
