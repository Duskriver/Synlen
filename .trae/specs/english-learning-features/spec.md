# 英语学习功能规格说明书 (English Learning Features Spec)

## 为什么 (Why)

用户希望在阅读英文书籍时，能够获得更好的辅助学习体验。具体包括：点击单词时显示发音、释义和例句；长按选择句子时进行语法分析并提供朗读功能。

## 变更内容 (What Changes)

### 1. 阅读器交互 (Web/JS)

- **单词点击**: 在 `lib/web_src/reader_assets.dart` 中增加 JS 逻辑，利用 `document.caretRangeFromPoint` 识别用户点击的单词。
- **句子长按**: 在 `lib/web_src/reader_assets.dart` 中增加 JS 逻辑，识别用户长按所在的完整句子。
- **高亮反馈**: 选中单词或句子时，在 Web 视图中给予视觉反馈（如背景色高亮）。

### 2. Flutter 阅读器渲染层 (Reader Renderer)

- **事件拦截**:
  - 修改 `ReaderRenderer` 的点击处理逻辑 (`_handleTap`)，优先检查是否点击了单词。如果是，则拦截翻页/菜单操作，弹出单词卡片。
  - 修改长按处理逻辑 (`_handleLongPressStart`)，优先检查是否选中了句子。如果是，弹出句子分析卡片。
- **回调接口**: 更新 `ReaderWebViewCallbacks`，增加 `onWordTap` (单词点击) 和 `onSentenceSelected` (句子选中) 回调。

### 3. API 服务 (Services)

- **FreeDictionaryService**: 调用 `https://freedictionaryapi.com/api/v1/openapi.json` (实际为 Free Dictionary API) 获取单词发音音频。
- **DeepSeekService**:
  - 单词模式：调用 DeepSeek API 获取单词的详细释义和例句。
  - 句子模式：调用 DeepSeek API 分析句子的成分和语法。
- **AliyunTTSService**: 调用阿里云 DashScope `qwen3-tts-flash` 模型，获取句子的朗读音频。

### 4. UI 组件 (UI)

- **WordDefinitionDialog**: 单词弹窗，显示发音按钮（点击播放）、释义、例句。
- **SentenceAnalysisDialog**: 句子弹窗，显示语法分析结果、朗读按钮（点击播放）。
- **AudioPlayer**: 集成音频播放能力，用于播放单词发音和 TTS 音频。

## 影响范围 (Impact)

- **受影响的 Specs**: 阅读器交互逻辑。
- **受影响的代码**:
  - `lib/web_src/reader_assets.dart`: 注入的 JS 代码。
  - `lib/src/features/reader/presentation/reader_renderer.dart`: 事件处理。
  - `lib/src/features/reader/presentation/reader_webview.dart`: 通信桥接。
  - 新增目录 `lib/src/features/learning/`: 存放服务和 UI 代码。

## 新增需求 (ADDED Requirements)

### 需求：单词交互

系统必须支持用户点击单词后获取信息。

- **当** 用户点击阅读器中的英文单词时。
- **系统** 识别该单词。
- **并且** 显示弹窗，包含：
  - 发音播放按钮 (来源: Free Dictionary API)。
  - 单词释义和例句 (来源: DeepSeek API)。

### 需求：句子交互

系统必须支持用户长按句子后进行分析。

- **当** 用户长按阅读器中的句子时。
- **系统** 选中该句子。
- **并且** 显示弹窗，包含：
  - 以专业英语老师视角讲解语法成分 (来源: DeepSeek API)。
  - 句子朗读按钮 (来源: Aliyun TTS `qwen3-tts-flash`)。

### 需求：API 集成

- **Free Dictionary API**: 用于获取单词发音。
- **DeepSeek API**: 用于获取单词深度释义和句子语法分析。
- **Aliyun DashScope API**: 用于句子 TTS 生成 (`qwen3-tts-flash` 模型)。

## 修改需求 (MODIFIED Requirements)

### 需求：阅读器点击处理

- **现有**: 点击屏幕边缘翻页，点击中间呼出菜单。
- **修改**: 点击时优先检测是否点击了文本单词。如果点击了单词，触发单词查询；否则执行原有翻页/菜单逻辑。

### 需求：阅读器长按处理

- **现有**: 长按图片进行查看。
- **修改**: 长按时优先检测是否长按了文本句子。如果选中句子，触发句子分析；否则执行原有逻辑（如图片查看）。
