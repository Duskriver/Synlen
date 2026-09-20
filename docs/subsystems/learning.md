# learning

learning 模块负责点词释义、长句分析与发音：内容来自 DeepSeek，单词发音优先取有道音频，其余语音由阿里云 TTS 生成；AI 服务密钥由用户自填。本页定义这些类型、语义与边界；学习数据流见 [architecture.md](../architecture.md#数据流)。

## 职责

- 学习入口：`LearningEntry` 是宿主（阅读器）唯一依赖的 application 接口。
- 用例编排：点词与长句共用 controller，按查询类型处理内容并转换错误。
- 内容获取：DeepSeek 释义 / 句子分析，英文单词发音优先直取有道美音 MP3。
- 语音：阿里云 DashScope 流式 PCM，按音色区分缓存。
- 缓存：四张学习缓存表 + 音频文件缓存，均为可重建数据。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `LearningEntry` | 宿主唯一入口：`showWord` 接收全局逻辑坐标锚点、可见词片段与阅读主题，`dismissWord` 只关闭自有词卡；`showSentence` 打开底部面板 | `lib/src/features/learning/application/learning_entry.dart` |
| `LearningController` / `LearningQuery` | 点词与长句共用的用例编排：按查询类型选仓库，读缓存 → 并行取正文与发音 → 状态机 | `lib/src/features/learning/application/learning_controller.dart` |
| `LearningRepository` / `LearningInfo` | 词/句学习仓库的 domain 抽象：查询信息、正文流、发音流与音频持久化；词正文流逐条输出已校验的 NDJSON，句正文流输出 Markdown 片段 | `lib/src/features/learning/domain/learning_repository.dart` |
| `WordLearningQuery` / `SentenceLearningQuery` | `LearningQuery` 的两个子类：词侧带上下文，句侧只有整句 | `lib/src/features/learning/domain/learning_query.dart` |
| `LearningControllerSession` | controller 的共享会话：仓储、音频协调器、取消令牌与 dispose 状态 | `lib/src/features/learning/application/learning_controller_support.dart` |
| `LearningDetailState` | 学习弹窗状态：加载中、文本、增量词条、音频与错误字段 | `lib/src/features/learning/application/learning_detail_state.dart` |
| `WordDefinition` / `WordSummary` / `WordSynonym` | 词条快照、双语简义与近义词区别；快照中 null 表示该部分尚未到达 | `lib/src/features/learning/domain/word_definition.dart` |
| `WordDefinitionParser` | 按简义、解释、近义词、构词顺序校验四条 NDJSON；格式错误不改变已有快照 | `lib/src/features/learning/domain/word_definition_parser.dart` |
| `LearningAudioCoordinator` | 音频生命周期：初始化、播放本地 / 远程 / PCM 流、缓存与错误上报；一个页面一个实例 | `lib/src/features/learning/application/learning_audio_coordinator.dart` |
| `LearningAudioPlayer` / `LearningStreamingAudioSession` | 播放器 seam 与流式播放会话 | `lib/src/features/learning/application/` |
| `WordRepository` / `SentenceRepository` | `LearningRepository` 的两个实现：查缓存 → 缺什么补什么 → 落库；词侧直取发音失败后转 TTS | `lib/src/features/learning/data/repositories/` |
| `DeepSeekService` | 释义与句子分析，密钥在运行时从安全存储读取 | `lib/src/features/learning/data/services/deep_seek_service.dart` |
| `AliyunTTSService` | 阿里云 DashScope 流式语音，输出 24 kHz 单声道 16 bit PCM | `lib/src/features/learning/data/services/aliyun_tts_service.dart` |
| `FreeDictionaryService` | `getPronunciationAudio` 获取有道美音的完整 MP3 字节；失败返回 null，取消继续向上传播 | `lib/src/features/learning/data/services/free_dictionary_service.dart` |
| `LearningCacheCleanupService` | 清空四张学习缓存表与全部音频缓存 | `lib/src/features/learning/data/services/learning_cache_cleanup_service.dart` |
| `WordLearningCacheStore` / `SentenceLearningCacheStore` / `SentencePronunciationCacheStore` | 文本与发音缓存表读写 | `lib/src/features/learning/data/stores/` |
| `LearningAudioFileStore` | 音频文件命名（含音色键）与按容量预算清退最旧文件 | `lib/src/features/learning/data/stores/learning_audio_file_store.dart` |
| `AliyunTtsVoice` | 49 个音色的英文名、中文名与描述；`voiceParam` 供请求，`cacheKey` 供缓存命名 | `lib/src/features/learning/domain/aliyun_tts_voice.dart` |
| `AudioStreamResult` / `AudioFormat` | 音频流结果：流 + 格式（mp3 / wav / pcm）+ 采样信息 + `cacheByVoice` | `lib/src/features/learning/domain/audio_stream_result.dart` |
| `LearningException` / `LearningErrorCode` | 领域异常与 8 个错误码 | `lib/src/features/learning/domain/learning_exception.dart` |
| `LearningCancellation` | 请求取消令牌，跨 controller、仓储与服务传播 | `lib/src/features/learning/domain/learning_cancellation.dart` |
| `resolveLearningErrorText` | 错误码到 l10n 文案的映射；`details` 只入日志 | `lib/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart` |

## 流程

1. 点词：`LearningEntry.showWord` → `LearningController` 按 `WordLearningQuery` 选 `WordRepository` 并建会话初始化音频 → `getInfo` 读缓存 → 缺正文时 `DeepSeekService` 流式生成，仓储合行校验后逐条更新词条；缺发音时先试 `FreeDictionaryService`（mp3），失败降级 `AliyunTTSService`（pcm）。
2. 长句：`LearningEntry.showSentence` → `LearningController` 按 `SentenceLearningQuery` 选 `SentenceRepository` → `getInfo` 读缓存 → 缺分析时 `DeepSeekService` 流式生成并落 `SentenceAnalyses`；发音固定走 `AliyunTTSService`。
3. 缓存键：词、句文本使用独立 [prompt 版本](core.md#关键类型)，只使相应文本缓存失效；词释义键含原词与上下文。发音缓存键为词或句的哈希，音频文件名带音色键。
4. 播放：`LearningAudioCoordinator.play` 按来源选本地文件、远程 URL 或 PCM 流；PCM 流按块喂入并做 8 ms 淡入淡出。
5. 清理：设置页 `CacheCleanup` 调 `LearningCacheCleanupService.cleanAll`，删四张缓存表并把音频缓存清到 0 字节。

## 边界与不变量

- 密钥只从 `FlutterSecureStorage` 读；未配置时抛 `LearningErrorCode.noDeepSeekApiKey` 或 `noAliyunTtsApiKey`。
- `LearningException.details` 不上屏；用户可见文案一律经 `resolveLearningErrorText` 映射。
- TTS 发音按音色区分缓存；切换音色后旧音色的 TTS 文件不会被命中。有道音频不依赖所选音色，以 `cacheByVoice: false` 缓存。
- 单词直连发音从请求到完整下载共用两秒预算，仅接受成功、非空且类型为 MP3 的响应；失败或超时转阿里云 TTS，查询取消不触发回退。数据去向与发送范围见[隐私说明](../user/privacy.md#离开设备的数据)。
- `build()` 中创建的音频协调器必须在 `ref.onDispose` 释放，`LearningControllerSession.dispose` 幂等。
- 音频缓存超过容量预算时按修改时间最旧优先清退。
- 学习缓存可重建，删除不影响用户图书与阅读进度。
- 请求取消经 `LearningCancellation` 传播，被取消的请求不写缓存。
- 词卡的遮罩消费外部点击；返回键或外部点击关闭词卡。入口在展示期间保活并阻止重复打开，打开与关闭各触发一次触觉反馈；关闭时释放词条请求与音频会话。
- 词卡宽度为可用屏宽的 84%，上限 380 逻辑像素；高度固定为安全视口的 35%，流式内容与切换标签不改变高度，超出部分内部滚动。优先向下，空间不足时向上；极小视口两侧均不足才缩到较大一侧的可用高度。
- 锚点与可见词片段从全局坐标转换到根导航器 overlay；包围框只定位卡片，各词片段分别着色，避免跨行包围框误标邻词。未传 `wordRects` 的调用沿用锚点标记，显式空列表不绘制标记。词卡与原词标记共用阅读主题和路由生命周期；阴影、描边与遮罩区分浮层和正文，坐标有效期由宿主控制。设计理由见[词卡反馈与直连发音](../../.agents/notes/implemented/bug-fix/2026-09-20-word-popover-feedback-and-pronunciation.md)。
- 简义包含原形、原词音标、词性与中英定义；原形只用于标题，朗读对象始终是被点击的词形。解释正文为中文，标签与加载、失败、空内容提示走 l10n。
- 词正文每条有效记录立即发布，不经过句子 Markdown 的节流缓冲；后续失败保留已验证内容并允许重试。只有四部分齐全且流成功结束才写入现有文本列；损坏缓存由 application 当作未命中重取。

## 已知限制与待办

- `aliyun_tts_voice.dart` 的 49 个音色名称与描述是产品目录数据，不迁 ARB；判断标准见 [TTS 音色目录与 LLM 提示词不迁入 ARB](../../.agents/notes/implemented/process/2026-09-08-keep-tts-voice-catalog-out-of-arb.md)。

## Dev Note

None.
