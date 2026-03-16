# Learning 模块说明

本文档说明 `learning` 模块当前的职责边界、数据模型与加载流程。目标只有两个：

1. 让后续维护者快速理解代码结构。
2. 明确“文本分析”和“音频发音”始终独立查询、独立请求、独立缓存。

## 1. 模块结构

`learning` 模块分为四层：

- `presentation`
  弹窗 UI，只负责渲染状态和触发用户动作。
- `application`
  Controller、状态模型、音频播放协调器。负责加载编排。
- `data/repositories`
  业务规则与外部服务编排。
- `data/stores`
  Isar 缓存读写与音频文件读写。

核心文件：

- `lib/src/features/learning/presentation/widgets/word_definition_dialog.dart`
- `lib/src/features/learning/presentation/widgets/sentence_analysis_dialog.dart`
- `lib/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart`
- `lib/src/features/learning/application/word_learning_controller.dart`
- `lib/src/features/learning/application/sentence_learning_controller.dart`
- `lib/src/features/learning/application/learning_audio_coordinator.dart`
- `lib/src/features/learning/application/learning_streaming_audio_session.dart`
- `lib/src/features/learning/data/repositories/word_repository.dart`
- `lib/src/features/learning/data/repositories/sentence_repository.dart`
- `lib/src/features/learning/data/stores/word_learning_cache_store.dart`
- `lib/src/features/learning/data/stores/sentence_learning_cache_store.dart`
- `lib/src/features/learning/data/stores/sentence_pronunciation_cache_store.dart`
- `lib/src/features/learning/data/stores/learning_audio_file_store.dart`

## 2. 入口

### 2.1 点击单词

1. 阅读器点击正文。
2. WebView JS 根据坐标提取单词与上下文。
3. Flutter 回调 `onWordTap(word, context)`。
4. 打开 `WordDefinitionDialog`。
5. `WordLearningController` 开始加载。

### 2.2 长按句子

1. 阅读器长按正文。
2. WebView JS 根据坐标提取句子。
3. Flutter 回调 `onSentenceSelected(sentence)`。
4. 打开 `SentenceAnalysisDialog`。
5. `SentenceLearningController` 开始加载。

## 3. 当前原则

### 3.1 文本和音频完全独立

无论是单词还是句子，都必须允许以下状态单独成立：

- 只有文本缓存
- 只有音频缓存
- 两者都有
- 两者都没有

因此：

- 查询时独立判断
- 缺失时独立请求
- 请求完成后独立持久化
- UI 不因为缺一项而阻塞另一项

### 3.2 UI 不编排业务

Dialog 不直接处理：

- 缓存命中判断
- 文本流拼接
- 音频流播放
- 文件落盘
- Isar 回写

这些都在 `application` 和 `data` 层完成。

## 4. 数据模型

### 4.1 单词

单词缓存分两类：

- `WordExplanation`
  文本解释缓存
- `WordPronunciation`
  音频路径缓存

缓存键：

- 文本：`word + context`
- 音频：`word`

这意味着同一单词在不同上下文下可以有不同解释，但音频共享。

### 4.2 句子

句子缓存也分两类：

- `SentenceAnalysis`
  句子分析文本缓存
- `SentencePronunciation`
  句子音频路径缓存

缓存键：

- 文本：`sentence`
- 音频：`sentence`

句子文本和音频现在是两张独立缓存表，不再共享一条 Isar 记录。

### 4.3 音频文件

音频二进制本体不放在 Isar，只放文件系统：

- 目录：`documents/audio/`
- 单词：`word_<safeWord>.mp3` / `word_<safeWord>.wav`
- 句子：`sentence_<stableHash>.wav`

## 5. 单词流程

### 5.1 查询阶段

`WordRepository.getWordInfo(word, context)` 会独立查询：

- 文本缓存：`WordLearningCacheStore.getExplanation`
- 音频缓存：`WordLearningCacheStore.getPronunciation` + `LearningAudioFileStore.resolveWordAudioPath`

返回：

- `explanation`
- `audioUrl`
- `hasCachedExplanation`
- `hasCachedAudio`

### 5.2 文本缺失时

1. Controller 调用 `getWordExplanationStream`
2. Repository 调用 `DeepSeekService.explainWordStream`
3. Controller 节流更新 UI 状态
4. 流结束后写入 `WordExplanation`

### 5.3 音频缺失时

1. Controller 调用 `getPronunciationStream`
2. Repository 先尝试词典音频，再降级到阿里云 TTS
3. `LearningStreamingAudioSession` 提供边下边播能力
4. 音频流结束后保存本地文件
5. 单独写入 `WordPronunciation`

## 6. 句子流程

### 6.1 查询阶段

`SentenceRepository.getSentenceInfo(sentence)` 会独立查询：

- 文本缓存：`SentenceLearningCacheStore.getSentence`
- 音频缓存：`SentencePronunciationCacheStore.getPronunciation` + `LearningAudioFileStore.resolveSentenceAudioPath`

返回：

- `analysis`
- `audioUrl`
- `hasCachedAnalysis`
- `hasCachedAudio`

### 6.2 文本缺失时

1. Controller 调用 `getSentenceAnalysisStream`
2. Repository 调用 `DeepSeekService.analyzeSentenceStream`
3. Controller 节流更新 UI 状态
4. 流结束后写入 `SentenceAnalysis`

### 6.3 音频缺失时

1. Controller 调用 `getPronunciationStream`
2. Repository 调用 `AliyunTTSService.generateAudioStream`
3. `LearningStreamingAudioSession` 提供边下边播能力
4. 音频流结束后保存本地文件
5. 单独写入 `SentencePronunciation`

## 7. 流式音频

阿里云 TTS 返回的是裸 PCM 流，播放器无法直接识别。

因此当前做法是：

1. 流式播放阶段先补一个占位 WAV 头
2. 播放器按 `audio/wav` 识别
3. 流结束后重新生成正确长度的 WAV 头
4. 落盘成最终 WAV 文件

这一逻辑统一收敛在：

- `LearningStreamingAudioSession`
- `LearningAudioCoordinator`

## 8. 错误处理

错误分为两类：

- 文本加载失败
- 音频加载失败

处理原则：

- 如果已有部分内容，保留已显示部分
- 失败项只影响自己
- 不允许“没有数据但看起来成功”

## 9. 自动化测试

当前 learning 模块已补仓库级测试，覆盖以下独立缓存场景：

- 单词：只有文本缓存
- 单词：只有音频缓存
- 句子：只有文本缓存
- 句子：只有音频缓存

测试文件：

- `test/features/learning/data/repositories/learning_repository_test.dart`

## 10. 已知限制

- 句子提取仍然不是跨多 DOM 节点拼句。
- 音频缓存目前没有容量淘汰策略。
- `just_audio` 仍依赖 `StreamAudioSource` 的实验性用法。
