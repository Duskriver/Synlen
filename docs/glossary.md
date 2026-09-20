# 领域术语

术语的唯一来源。写代码前先查；发现模糊或冲突的术语立即改这里。第一列反引号里的标识符必须与代码声明一致（`dart run tool/doc_gates.dart` 校验）。"禁用别称"约束的是**代码标识符、注释与文档**里的说法，不约束面向用户的界面文案——界面用什么词由 l10n 决定。

## 藏书

| 术语 | 定义 | 禁用别称 |
|---|---|---|
| `ShelfBook` | 书架上的书：轻量 drift 行，只含核心元数据（标题、作者、封面）与阅读进度，用于列表展示。 | Book、图书、书本 |
| `BookFormat` | 书籍文件格式枚举（`epub` / `txt`），持久化在 ShelfBook 与 BookManifest 的 `format` 列，决定导入解析器与阅读时内容供给的分支。 | 文件类型、FileType |
| `BookManifest` | 阅读引擎使用的完整书籍结构（spine、TOC），仅打开阅读器时查询。EPUB 的 spine 指向包内条目路径；TXT 的 spine 指向虚拟章节路径（`txt/chapter_N.xhtml`）。 | manifest、内容清单、目录结构 |
| `SpineItem` | spine 中的线性阅读顺序条目，决定上一页 / 下一页导航。TXT 条目通过 `sourceRange` 记录章节在归一化 UTF-8 字节流中的范围（`"start-end"`，左闭右开）。 | 章节项、spine 项 |
| `ShelfGroup` | 书架分组，用户自定义的书目分类。 | 分类夹、书架分类 |
| `ShelfBookSortBy` | 书架排序依据。 | 排序方式、SortBy |
| `BookProgress` | 完整 Locator JSON 与书架显示百分比；保留文本上下文和 SDK 扩展字段，恢复不使用页码推算。 | 阅读进度对象、Progress |
| `UnifiedImportService` | 把书籍文件加入藏书的统一编排入口：平台选择、导入缓存与哈希。 | 导入流程、Ingest、ImportService |
| `ProgressLog` / `BackupImportProgress` / `ImportResult` | 导入与恢复的进度事件与结果值对象。data 发事件、application 编排、presentation 渲染三方都要用，因此落在 domain，避免 data → application 的逆向依赖。 | 进度回调、导入状态 |
| Cover（封面） | 书的封面图片，导入时从 EPUB 提取生成，独立于书籍文件存储。TXT 无封面。 | 缩略图、书封 |

## 阅读

| 术语 | 定义 | 禁用别称 |
|---|---|---|
| `ReaderSettings` | 阅读器可配置项：字号、边距、主题、外链处理、翻页动画、自定义字体。 | 阅读配置、ReadingPrefs |
| `EpubTheme` | 阅读器配色主题，与全局 `AppThemeSettings` 解耦。 | 阅读主题配置、ThemePreset |
| `ReaderLinkHandling` | 阅读器对外部链接点击的处理策略：ask / always / never。 | LinkHandling、链接策略 |
| `ReaderPageAnimation` | 翻页动画样式：none / slide。 | PageAnimation、翻页效果 |
| `ReadiumSession` | 一次阅读会话：打开出版物、定位与主题重排、过滤过期事件、进度提交及原生资源释放。 | 阅读会话对象、Session |
| `ReaderSessionFactory` | 阅读器装配入口，组合内容供给、原生能力与进度持久化，并串行交接出版物。 | 阅读器工厂、ReaderFactory |
| `ReadiumPublicationSource` | 准备 Readium 所需的本地出版物文件及书目上下文；TXT 以虚拟章节生成派生 EPUB。 | — |

## 学习

| 术语 | 定义 | 禁用别称 |
|---|---|---|
| `LearningEntry` | 宿主（阅读器）调用学习能力的唯一 application 入口。 | 学习服务、LearningService |
| `LearningController` | 点词释义与长句分析共用的用例编排，持有页面状态并做错误转换。 | 学习管理器、LearningManager |
| `LearningException` / `LearningErrorCode` | 领域异常与错误码；展示层经 `resolveLearningErrorText` 映射为 l10n 文案，`details` 只入日志。 | 学习错误、ApiError |
| `AudioStreamResult` / `AudioFormat` | TTS 音频流结果：流 + 格式（mp3 / wav / pcm）+ 采样信息；audioUrl 播放与流式播放共用。 | 音频结果、TTS 返回 |
| `AliyunTtsVoice` | TTS 音色枚举，含英文名、中文名与音色描述，由设置模块选择。 | voice、VoiceEnum |
| `LearningAudioCoordinator` | 学习模块内负责音频生命周期（初始化、播放、缓存、错误上报）的协调器，一个学习页面一个实例。 | AudioCoordinator、audio player、AudioService |
| `WordExplanation` / `WordPronunciation` / `SentenceAnalysis` / `SentencePronunciation` | 学习缓存表：单词释义、单词发音、句子分析、句子发音。发音按音色区分缓存。 | 学习记录、缓存表 |

## 设置

| 术语 | 定义 | 禁用别称 |
|---|---|---|
| `ImportedFont` | 用户导入的自定义字体（文件 + 元数据），供阅读器选用。 | 自定义字体对象、FontFile |
| `FontManagerNotifier` | 字体导入 / 删除 / 可用字体列表的管理者。 | FontManager、字体服务、FontService |
| `AppThemeSettings` | 应用全局主题设置（明暗模式、配色），与 `EpubTheme` 解耦。 | 全局主题配置、AppThemeConfig |

## 跨模块接口

| 术语 | 定义 | 禁用别称 |
|---|---|---|
| `BookQueries` | library 暴露给其他 feature 的书目查询接口；宿主经它读书目，不依赖 library 仓库。 | 书目服务、LibraryService |
| 组合面（composition surface） | 允许依赖其他 feature `application` 层的特殊模块，当前仅 `settings`。新增组合面必须先改决策记录。 | 聚合层、facade |
| 宿主（host） | 调用其他 feature 能力的模块，当前是 `reader` 调用 learning 与 settings；只经对方的 `application` 入口。 | 调用方、上层模块 |

## Dev Note

None.
