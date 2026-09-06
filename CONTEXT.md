# Synlen Context

Synlen 是一个本地书籍阅读器：导入 EPUB / TXT 建立藏书，阅读并记录进度，支持句子/单词学习与 TTS 发音。本文档是领域统一语言，写作代码前先查术语；发现模糊或冲突立即更新这里。

## 藏书

**ShelfBook**:
书架上的书。轻量 drift 表，只含核心元数据（标题、作者、封面）与阅读进度，用于列表展示与同步。
_Avoid_: Book、图书、书本

**BookFormat**:
书籍文件格式枚举（`epub` / `txt`），持久化在 ShelfBook 与 BookManifest 的 `format` 列，决定导入解析器与阅读时内容供给的分支。
_Avoid_: 文件类型、FileType

**BookManifest**:
阅读引擎使用的完整书籍结构（spine、TOC），仅打开阅读器时查询。EPUB 的 spine 指向包内条目路径；TXT 的 spine 指向虚拟章节路径（`txt/chapter_N.xhtml`）。
_Avoid_: manifest、内容清单、目录结构

**SpineItem**:
spine 中的线性阅读顺序条目，决定上一页/下一页导航。TXT 条目通过 `sourceRange` 记录章节在归一化 UTF-8 字节流中的范围（`"start-end"`，左闭右开）。
_Avoid_: 章节项、spine 项（统一用英文）

**ShelfGroup**:
书架分组，用户自定义的书目分类。

**Progress**:
每本书最后确认的阅读位置及全书完成比例；加载中的临时页码不算阅读进度。

**ReadingProgress**:
完成分页后的阅读位置，包含线性阅读顺序中的章节、章内页码和章内总页数。

**Import**:
把书籍文件加入藏书的过程。EPUB 采用 "stream-from-zip" 策略：以压缩形式存盘，不整包解压；TXT 导入时解码（BOM → UTF-8 → GBK）并归一化为 UTF-8 单文件存盘，阅读时不再关心原始编码。
_Avoid_: 导入流程、Ingest

**Cover**:
书的封面图片，导入时从 EPUB 提取生成，独立于书籍文件存储。TXT 无封面。

## 阅读

**ReaderSettings**:
阅读器可配置项：字号、边距、主题、外链处理、翻页动画、自定义字体等。
_Avoid_: 阅读配置、ReadingPrefs

**EpubTheme**:
阅读器配色主题（非应用全局主题 AppTheme），与 Settings 的全局主题解耦。

**LinkHandling**:
阅读器对外部链接点击的处理策略：ask / always / never。

**PageAnimation**:
翻页动画样式：none / slide。

## 学习

**Word**:
单词学习条目，含释义（Explanation）与发音（Pronunciation）。

**Sentence**:
句子学习条目，含句子分析（SentenceAnalysis）与发音。

**Explanation**:
单词的释义内容，可缓存。

**Pronunciation**:
单词/句子的发音，分 `WordPronunciation` 与 `SentencePronunciation`，可缓存，缓存按音色区分（cacheByVoice）。

**SentenceAnalysis**:
句子的语法/结构分析文本。

**AudioStreamResult**:
TTS 音频流结果：流 + 格式（mp3/wav/pcm）+ 采样信息。audioUrl 播放与流式播放共用。
_Avoid_: 音频结果、TTS 返回

**AliyunTtsVoice**:
TTS 音色枚举，含英文名、中文名与音色描述，由设置模块选择。
_Avoid_: voice、音色（代码命名必须用 AliyunTtsVoice）

**AudioCoordinator**:
学习模块内负责音频生命周期（初始化、播放、缓存、错误上报）的协调器，一个学习页面一个实例。
_Avoid_: audio player、AudioService

## 设置

**ImportedFont**:
用户导入的自定义字体（文件 + 元数据），供阅读器选用。

**FontManager**:
字体导入/删除/可用字体列表的管理者。
_Avoid_: 字体服务、FontService
