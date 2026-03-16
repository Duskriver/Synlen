# 单词分析与句子分析业务流程说明

本文档用于 AI 或后续维护者快速接手当前项目中的 learning 模块实现，重点说明以下内容：

- 阅读器里“点击单词”和“长按句子”的入口链路
- 单词分析与句子分析的数据获取流程
- 文本和音频的缓存策略
- 流式音频播放与落盘逻辑
- 当前实现约束与注意事项

相关代码主要位于：

- `lib/src/features/reader/presentation/reader_screen.dart`
- `lib/src/features/reader/presentation/reader_renderer.dart`
- `lib/src/features/reader/presentation/reader_webview.dart`
- `lib/src/features/learning/data/repositories/word_repository.dart`
- `lib/src/features/learning/data/repositories/sentence_repository.dart`
- `lib/src/features/learning/data/services/deep_seek_service.dart`
- `lib/src/features/learning/data/services/aliyun_tts_service.dart`
- `lib/src/features/learning/data/services/free_dictionary_service.dart`
- `lib/src/features/learning/presentation/widgets/word_definition_dialog.dart`
- `lib/src/features/learning/presentation/widgets/sentence_analysis_dialog.dart`

## 1. 整体入口

### 1.1 点击单词

1. 用户在阅读器内点击正文。
2. Flutter 层 `ReaderRenderer` 把点击坐标交给 WebView。
3. WebView 内的 JS 根据坐标取文本光标位置，向两侧扩展出一个英文单词。
4. 如果识别成功，通过 `onWordTap(word, context)` 回传 Flutter。
5. `ReaderScreen.handleWordTap` 打开 `WordDefinitionDialog`。

这里的 `context` 会优先复用句子提取逻辑，从点击位置所在 `text node` 内按标点扩成一句；如果提取失败，再回退到当前 `text node` 前后各截取一段文本。它仍然作为单词上下文提示和缓存键的一部分。

### 1.2 长按句子

1. 用户在阅读器内长按正文。
2. Flutter 层先让 WebView 检查长按位置是否是图片。
3. 如果不是图片，JS 根据坐标取文本光标位置，并尝试向左右扩展出一个句子。
4. 成功后通过 `onSentenceSelected(sentence)` 回传 Flutter。
5. `ReaderScreen.handleSentenceSelected` 打开 `SentenceAnalysisDialog`。

当前句子提取基于单个 text node 扩展，不是跨多个 DOM 节点拼句，所以富文本断句场景仍可能有截断。

## 2. 单词分析流程

### 2.1 首次进入弹窗

`WordDefinitionDialog` 初始化后会：

1. 创建 `AudioPlayer`
2. 调用 `WordRepository.getWordInfo(word, context)`
3. 同时拿到两类状态
   - 是否已有释义缓存
   - 是否已有音频缓存


### 2.2 单词文本获取

单词释义来自 `DeepSeekService.explainWordStream(word, context)`。

流程如下：

1. Dialog 发现没有释义缓存时，调用 `WordRepository.getWordExplanationStream`
2. Repository 调用 DeepSeek 流式接口
3. UI 一边接收 chunk，一边节流更新 `_explanation`
4. 流结束后，Repository 立即把完整 Markdown 写入 Isar
5. 单词释义写库不再等待音频结果，也不写入音频路径

### 2.3 单词音频获取

单词发音优先级：

1. `FreeDictionaryService` 获取词典音频 URL
2. 如果成功，直接下载 mp3 流
3. 如果失败，降级到 `AliyunTTSService.generateAudioStream(word)`，返回 PCM 流

Dialog 会把音频流包装成 `_StreamingAudioSource` 交给 `just_audio`，从而实现边下边播。

### 2.4 单词音频落盘

音频缓存目录：

- `documents/audio/`

单词音频命名：

- `word_<safeWord>.mp3`
- `word_<safeWord>.wav`

其中：

- 词典音频通常是 mp3
- 阿里云 TTS 返回的是 PCM，保存前会补成 WAV

落盘流程：

1. 流式播放时，PCM 先补一个“占位 WAV 头”供播放器识别
2. 下载结束后，取出原始 PCM 数据
3. 重新生成带正确长度的 WAV 头
4. 保存为本地文件
5. Repository 将音频路径写入独立的 `WordPronunciation` 缓存

### 2.5 单词缓存

单词缓存分两层：

1. 文本缓存：Isar `WordExplanation`
2. 音频元数据缓存：Isar `WordPronunciation`
3. 音频文件缓存：本地文件系统

`WordExplanation` 的主键由 `word + context` 的稳定哈希生成，`WordPronunciation` 的主键由 `word` 的稳定哈希生成，因此：

- 同一单词在不同上下文里会被视为不同缓存项
- 同一单词音频缓存是共享的，不区分上下文
- 文本和音频可以独立命中、独立回填

## 3. 句子分析流程

### 3.1 当前核心原则

句子分析和句子音频必须独立缓存、独立查询。

这意味着以下几种状态都合法：

1. 只有分析文本，没有音频
2. 只有音频，没有分析文本
3. 二者都有
4. 二者都没有

UI 不允许因为缺其中一项而阻塞另一项展示。

### 3.2 句子首次进入弹窗

`SentenceAnalysisDialog` 初始化后会：

1. 创建 `AudioPlayer`
2. 调用 `SentenceRepository.getSentenceInfo(sentence)`
3. 分别拿到
   - `analysis`
   - `audioUrl`
   - `hasCachedAnalysis`
   - `hasCachedAudio`
4. 立即展示已有部分
5. 只补请求缺失部分

例如：

- 有分析没音频：先显示分析，再后台拉音频
- 有音频没分析：先允许播放音频，再后台拉分析
- 都有：直接展示，不再请求
- 都没有：文本和音频都启动异步请求

### 3.3 句子文本获取

句子分析来自 `DeepSeekService.analyzeSentenceStream(sentence)`。

流程如下：

1. Dialog 发现没有分析缓存时，调用 `SentenceRepository.getSentenceAnalysisStream`
2. Repository 调用 DeepSeek 流式接口
3. UI 节流更新 `_analysis`
4. 流结束后写入 Isar `SentenceAnalysis`
5. 如果音频当时已经准备好，则一起写入 `audioUrl`
6. 如果音频稍后才拿到，则由单独的 `persistAudioPath` 回填

### 3.4 句子音频获取

句子音频只走阿里云 TTS：

- `AliyunTTSService.generateAudioStream(sentence)`

返回的是 PCM 流。

Dialog 逻辑：

1. 创建 `_StreamingAudioSource`
2. 调用 `AudioPlayer.setAudioSource`
3. 用户此时即可播放流式音频
4. 同时缓冲所有字节到内存
5. 流结束后立刻写入本地文件
6. 写完后回填 Isar 中的 `audioUrl`

这满足“支持流式播放，在完全获取后立即缓存到本地”的要求。

### 3.5 句子音频缓存

句子音频缓存目录同样位于：

- `documents/audio/`

当前命名方式：

- `sentence_<stableHash>.wav`

这里已经从旧版的 `sentence.hashCode` 改为稳定哈希，避免跨进程或升级后找不到旧文件。

同时为了兼容旧版本，查询时会同时尝试：

1. 新版稳定哈希文件名
2. 旧版 `hashCode` 文件名

因此旧缓存不会立刻失效。

### 3.6 句子缓存

句子缓存分两层：

1. 文本缓存：Isar `SentenceAnalysis`
2. 音频缓存：本地文件系统

`SentenceAnalysis` 以 `sentence` 唯一索引作为文本缓存键；音频文件名则由稳定哈希决定。

## 4. 流式播放实现细节

单词和句子共用一套思路，分别在各自 Dialog 中实现了 `_StreamingAudioSource`。

### 4.1 为什么需要自定义音频源

外部服务返回的是网络流，不是完整文件。

为了实现：

- 边下载边播放
- 流结束后再缓存到本地

需要一个能一边向播放器供数、一边自己缓冲字节的中间层。

### 4.2 PCM 为什么要补 WAV 头

阿里云返回的是裸 PCM 数据，播放器无法直接按音频文件识别。

因此在流式阶段先补一个长度占位的 WAV 头：

- 播放器看到的是 `audio/wav`
- 内部真实写入的仍然是 WAV 头 + PCM 数据

待流完全结束后，再重新生成正确长度的 WAV 头，保存最终文件。

## 5. 错误处理

当前流式服务不再静默吞错，而是统一抛出 `LearningException` 或包装后的错误信息。

这样 UI 可以区分：

- 文本加载失败
- 音频加载失败
- 二者都失败

表现层策略：

1. 如果已有部分内容，则保留已显示内容
2. 缺失项失败时只展示对应错误
3. 不再出现“空白但看起来像成功”的状态

## 6. 当前缓存查询策略总结

### 6.1 单词

- 释义缓存：`word + context`
- 音频缓存：`word`
- 文本和音频独立判断

### 6.2 句子

- 分析缓存：`sentence`
- 音频缓存：`sentence stableHash`
- 文本和音频独立判断

## 7. 重要约束与已知事实

1. 单词上下文现在优先来自点击位置所在 `text node` 内的句子提取；失败时才回退到局部截断文本，因此仍不是严格跨节点整句。
2. 句子提取仍然偏启发式，复杂 DOM 结构下可能截断。
3. 音频缓存当前没有独立的容量淘汰策略。
4. Dialog 内部负责发起加载、流式播放和落盘，没有再单独抽一层状态机。
5. `just_audio` 的 `StreamAudioSource` 当前属于项目里有意使用的实验性 API，用于实现流式播放。

## 8. 推荐的后续优化方向

如果后续继续演进，优先考虑：

1. 为单词和句子增加请求去重，避免连续点击同一项时重复打 AI/TTS
2. 给音频缓存增加 LRU 或总容量限制
3. 把句子提取从单 text node 扩展为跨 DOM 节点拼接
4. 将 Dialog 内部的加载状态抽到单独的 ViewModel/Notifier
5. 为 learning 模块补自动化测试，覆盖“只有文本缓存”与“只有音频缓存”的场景
