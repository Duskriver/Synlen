# 任务列表 (Tasks)

- [x] 任务 1: 添加项目依赖
  - [x] 在 `pubspec.yaml` 中添加 `dio` (用于网络请求)。
  - [x] 在 `pubspec.yaml` 中添加 `just_audio` (用于音频播放)。
  - [x] 执行 `flutter pub get`。

- [x] 任务 2: 实现 JS 交互逻辑 (`lib/web_src/reader_assets.dart`)
  - [x] 实现 `checkWordAt(x, y)` JS 函数：使用 `document.caretRangeFromPoint` 获取点击位置的单词，返回单词文本和上下文。
  - [x] 实现 `checkSentenceAt(x, y)` JS 函数：识别长按位置所在的完整句子，返回句子文本。
  - [x] 更新 `EpubReader` 类，在 `checkTapElementAt` 中增加对单词的检测，在 `checkElementAt` (长按) 中增加对句子的检测。
  - [x] 定义与 Flutter 通信的消息格式：`onWordTap` 和 `onSentenceSelected`。

- [x] 任务 3: 实现 Flutter 端桥接与事件处理
  - [x] 更新 `ReaderWebViewCallbacks` 类，增加 `onWordTap` 和 `onSentenceSelected` 回调。
  - [x] 更新 `ReaderWebView` 的 `javascriptChannels` 或 `onConsoleMessage` 处理逻辑，接收 JS 发送的单词/句子事件。
  - [x] 在 `ReaderRenderer` 中实现回调逻辑，暂时打印日志验证接收成功。

- [x] 任务 4: 实现 API 服务 (`lib/src/features/learning/data/services/`)
  - [x] 创建 `FreeDictionaryService`：实现获取单词发音 URL 的逻辑。
  - [x] 创建 `DeepSeekService`：
    - [x] 实现 `explainWord(word)`：调用 DeepSeek API 获取单词释义和例句。
    - [x] 实现 `analyzeSentence(sentence)`：调用 DeepSeek API 获取语法分析。
  - [x] 创建 `AliyunTTSService`：
    - [x] 实现 `generateAudio(text)`：调用 DashScope `qwen3-tts-flash` 接口，处理 POST 请求，获取音频 URL 或数据。
  - [x] 创建 `LearningRepository`：封装上述服务，提供统一接口。

- [x] 任务 5: 实现 UI 弹窗组件 (`lib/src/features/learning/presentation/widgets/`)
  - [x] 创建 `WordDefinitionDialog`：展示单词、发音按钮、释义内容。
  - [x] 创建 `SentenceAnalysisDialog`：展示句子、TTS 播放按钮、语法分析内容。
  - [x] 集成 `just_audio` 实现音频播放功能。

- [x] 任务 6: 集成与联调
  - [x] 在 `ReaderRenderer` 中，当触发 `onWordTap` 时显示 `WordDefinitionDialog`。
  - [x] 在 `ReaderRenderer` 中，当触发 `onSentenceSelected` 时显示 `SentenceAnalysisDialog`。
  - [x] 验证点击单词不触发翻页。
  - [x] 验证长按句子不冲突。
  - [x] 验证 API 调用和音频播放正常。

# 任务依赖 (Task Dependencies)
- 任务 3 依赖 任务 2。
- 任务 5 依赖 任务 1。
- 任务 6 依赖 任务 3, 任务 4, 任务 5。
