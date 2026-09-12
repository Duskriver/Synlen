# learning

learning 模块负责点词释义、长句分析与 TTS 发音：内容来自 DeepSeek，语音来自阿里云 TTS，密钥由用户自填。本页 owns 这些类型、语义与边界；学习数据流见 [architecture.md](../architecture.md#数据流)。

## 职责

- 学习入口：`LearningEntry` 是宿主（阅读器）唯一依赖的 application 接口。
- 用例编排：点词与长句两个 controller，各自持有页面状态并做错误转换。
- 内容获取：DeepSeek 释义 / 句子分析，英文单词发音优先走免费词典。
- 语音：阿里云 DashScope 流式 PCM，按音色区分缓存。
- 缓存：四张学习缓存表 + 音频文件缓存，均为可重建数据。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `LearningEntry` | 宿主唯一入口：`showWord` / `showSentence`，用根导航器弹底部面板 | `lib/src/features/learning/application/learning_entry.dart` |
| `LearningController` / `LearningQuery` | 点词与长句共用的用例编排：按查询类型选仓库，读缓存 → 并行取正文与发音 → 状态机 | `lib/src/features/learning/application/learning_controller.dart` |
| `LearningRepository` / `LearningInfo` | 词/句学习仓库的 domain 抽象：查询信息、正文流、发音流与音频持久化；`LearningInfo` 为文本与音频的缓存状态 | `lib/src/features/learning/domain/learning_repository.dart` |
| `WordLearningQuery` / `SentenceLearningQuery` | `LearningQuery` 的两个子类：词侧带上下文，句侧只有整句 | `lib/src/features/learning/domain/learning_query.dart` |
| `LearningControllerSession` | controller 的共享会话：仓储、音频协调器、取消令牌与 dispose 状态 | `lib/src/features/learning/application/learning_controller_support.dart` |
| `LearningDetailState` | 学习弹窗状态：加载中、内容、音频与错误字段 | `lib/src/features/learning/application/learning_detail_state.dart` |
| `LearningAudioCoordinator` | 音频生命周期：初始化、播放本地 / 远程 / PCM 流、缓存与错误上报；一个页面一个实例 | `lib/src/features/learning/application/learning_audio_coordinator.dart` |
| `LearningAudioPlayer` / `LearningStreamingAudioSession` | 播放器 seam 与流式播放会话 | `lib/src/features/learning/application/` |
| `WordRepository` / `SentenceRepository` | `LearningRepository` 的两个实现：查缓存 → 缺什么补什么 → 落库；词侧保留免费词典 mp3 降级 | `lib/src/features/learning/data/repositories/` |
| `DeepSeekService` | 释义与句子分析，密钥在运行时从安全存储读取 | `lib/src/features/learning/data/services/deep_seek_service.dart` |
| `AliyunTTSService` | 阿里云 DashScope 流式语音，输出 24 kHz 单声道 16 bit PCM | `lib/src/features/learning/data/services/aliyun_tts_service.dart` |
| `FreeDictionaryService` | 英文单词发音 URL（mp3）与词典条目，失败时降级到 TTS | `lib/src/features/learning/data/services/free_dictionary_service.dart` |
| `LearningCacheCleanupService` | 清空四张学习缓存表与全部音频缓存 | `lib/src/features/learning/data/services/learning_cache_cleanup_service.dart` |
| `WordLearningCacheStore` / `SentenceLearningCacheStore` / `SentencePronunciationCacheStore` | 文本与发音缓存表读写 | `lib/src/features/learning/data/stores/` |
| `LearningAudioFileStore` | 音频文件命名（含音色键）与按容量预算清退最旧文件 | `lib/src/features/learning/data/stores/learning_audio_file_store.dart` |
| `AliyunTtsVoice` | 49 个音色的英文名、中文名与描述；`voiceParam` 供请求，`cacheKey` 供缓存命名 | `lib/src/features/learning/domain/aliyun_tts_voice.dart` |
| `AudioStreamResult` / `AudioFormat` | 音频流结果：流 + 格式（mp3 / wav / pcm）+ 采样信息 + `cacheByVoice` | `lib/src/features/learning/domain/audio_stream_result.dart` |
| `LearningException` / `LearningErrorCode` | 领域异常与 8 个错误码 | `lib/src/features/learning/domain/learning_exception.dart` |
| `LearningCancellation` | 请求取消令牌，跨 controller、仓储与服务传播 | `lib/src/features/learning/domain/learning_cancellation.dart` |
| `resolveLearningErrorText` | 错误码到 l10n 文案的映射；`details` 只入日志 | `lib/src/features/learning/presentation/widgets/learning_detail_dialog_view.dart` |

## 流程

1. 点词：`LearningEntry.showWord` → `LearningController` 按 `WordLearningQuery` 选 `WordRepository` 并建会话初始化音频 → `getInfo` 读缓存 → 缺正文时 `DeepSeekService` 流式生成并落 `WordExplanations`；缺发音时先试 `FreeDictionaryService`（mp3），失败降级 `AliyunTTSService`（pcm）。
2. 长句：`LearningEntry.showSentence` → `LearningController` 按 `SentenceLearningQuery` 选 `SentenceRepository` → `getInfo` 读缓存 → 缺分析时 `DeepSeekService` 流式生成并落 `SentenceAnalyses`；发音固定走 `AliyunTTSService`。
3. 缓存键：`wordExplanationId` 含 `kLearningTextPromptVersion`，释义缓存随 prompt 版本失效；发音缓存键为词或句的哈希，音频文件名带音色键。
4. 播放：`LearningAudioCoordinator.play` 按来源选本地文件、远程 URL 或 PCM 流；PCM 流按块喂入并做 8 ms 淡入淡出。
5. 清理：设置页 `CacheCleanup` 调 `LearningCacheCleanupService.cleanAll`，删四张缓存表并把音频缓存清到 0 字节。

## 边界与不变量

- 密钥只从 `FlutterSecureStorage` 读；未配置时抛 `LearningErrorCode.noDeepSeekApiKey` 或 `noAliyunTtsApiKey`。
- `LearningException.details` 不上屏；用户可见文案一律经 `resolveLearningErrorText` 映射。
- 发音按音色区分缓存；切换音色后旧音色的音频文件不会被命中。
- `build()` 中创建的音频协调器必须在 `ref.onDispose` 释放，`LearningControllerSession.dispose` 幂等。
- 音频缓存超过容量预算时按修改时间最旧优先清退。
- 学习缓存可重建，删除不影响用户图书与阅读进度。
- 请求取消经 `LearningCancellation` 传播，被取消的请求不写缓存。

## 已知限制与待办

- `aliyun_tts_voice.dart` 的 49 个音色名称与描述是产品目录数据，不迁 ARB；判断标准见 [TTS 音色目录与 LLM 提示词不迁入 ARB](../../.agents/notes/implemented/process/2026-09-08-keep-tts-voice-catalog-out-of-arb.md)。

## Dev Note

None.
