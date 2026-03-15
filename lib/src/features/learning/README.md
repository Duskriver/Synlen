# 学习辅助模块 (Learning Feature)

## 模块简介
本模块主要提供基于 AI 的语言学习辅助功能，包括句子语法分析、单词释义以及语音朗读。通过集成 DeepSeek AI 和阿里云 TTS 等服务，为用户提供深度的阅读理解支持。

## 目录结构
```
lib/src/features/learning/
├── data/
│   ├── repositories/       # 数据仓库层，负责业务逻辑和数据获取
│   │   ├── learning_repository_provider.dart # Riverpod Providers 定义
│   │   ├── sentence_repository.dart          # 句子分析相关逻辑
│   │   └── word_repository.dart              # 单词释义相关逻辑
│   └── services/           # 服务层，负责与外部 API 交互
│       ├── aliyun_tts_service.dart           # 阿里云语音合成服务
│       ├── deep_seek_service.dart            # DeepSeek AI 分析服务
│       └── free_dictionary_service.dart      # 免费词典 API 服务
├── domain/                 # 领域层，定义数据模型
│   ├── sentence_analysis.dart  # 句子分析数据模型 (Isar Collection)
│   ├── word_explanation.dart   # 单词释义数据模型 (Isar Collection)
│   └── word_pronunciation.dart # 单词发音数据模型 (Isar Collection)
└── presentation/           # 表现层，UI 组件
    └── widgets/
        ├── sentence_analysis_dialog.dart     # 句子分析展示弹窗
        └── word_definition_dialog.dart       # 单词释义展示弹窗
```

## 核心组件说明

### 1. 数据模型 (Domain)
使用 **Isar** 数据库进行本地缓存，以减少 API 调用并支持离线访问。
*   **SentenceAnalysis**: 存储句子的语法分析结果、朗读音频路径及更新时间。
*   **WordExplanation**: 存储单词在特定上下文中的释义及更新时间。
*   **WordPronunciation**: 存储单词发音音频路径及更新时间。

### 2. 服务层 (Services)
*   **DeepSeekService**: 
    *   调用 DeepSeek API (`deepseek-chat`) 进行自然语言处理。
    *   支持流式输出 (Stream)，提升用户体验。
    *   功能：分析句子结构、解释单词含义（结合上下文）。
*   **AliyunTTSService**:
    *   调用阿里云 DashScope API (`qwen3-tts-flash`) 生成语音。
    *   支持流式音频数据获取。
    *   功能：为句子和单词提供高质量的朗读服务。
*   **FreeDictionaryService**:
    *   调用 `dictionaryapi.dev` 获取单词发音。
    *   功能：作为单词发音的首选来源（免费且地道）。

### 3. 数据仓库 (Repositories)
负责协调服务层和本地数据库，实现"缓存优先"策略。
*   **SentenceRepository**:
    *   `getSentenceInfo`: 优先从数据库获取缓存的分析结果。
    *   `getSentenceAnalysisStream`: 若无缓存，调用 DeepSeek 流式获取分析结果并自动存入数据库。
    *   `getPronunciationStream`: 调用阿里云 TTS 获取音频流，并保存为本地文件。
*   **WordRepository**:
    *   `getWordInfo`: 优先从数据库获取缓存的单词释义。
    *   `getPronunciationStream`: 发音获取策略为 **FreeDictionary API -> 阿里云 TTS (降级方案)**。
    *   将释义和音频分别持久化到独立缓存，避免上下文释义与发音缓存互相污染。

### 4. 表现层 (Presentation)
*   **SentenceAnalysisDialog**: 
    *   展示句子的语法分析（Markdown 渲染）。
    *   提供音频播放功能，支持边下边播。
*   **WordDefinitionDialog**: 
    *   展示单词的详细释义和例句。
    *   提供单词发音播放。

## 数据流向与缓存策略
1.  **请求发起**: UI 组件 (如 `SentenceAnalysisDialog`) 通过 Riverpod 读取 Repository。
2.  **缓存检查**: Repository 首先查询 Isar 数据库。
    *   **命中缓存**: 直接返回 `isFromCache: true` 及数据，UI 立即展示。
    *   **未命中**: 返回空数据，通知 UI 启动异步加载。
3.  **异步加载 (Streams)**:
    *   **分析数据**: UI 监听 Repository 提供的 Stream，实时展示 AI 生成的 Markdown 内容。
    *   **音频数据**: UI 监听音频 Stream，实现流式播放；Repository 同时将完整音频写入本地文件系统。
4.  **持久化**: 当流式数据接收完毕后，Repository 将完整内容写入 Isar 数据库，供下次直接使用。

## 外部依赖
*   **DeepSeek API**: 用于智能分析和释义。
*   **Aliyun DashScope (通义千问)**: 用于语音合成 (TTS)。
*   **Free Dictionary API**: 用于获取英文单词发音。
*   **Isar**: 用于本地数据持久化。
*   **Riverpod**: 用于状态管理和依赖注入。
