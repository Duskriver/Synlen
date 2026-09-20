# Agent Note: 词/句学习 controller 与 repository 合并

Status: implemented

## Problem

词学习与句学习的编排逻辑整段复制两份。controller 侧 `word_learning_controller.dart`（约 230 行）与 `sentence_learning_controller.dart`（约 210 行）的 `_loadData` / `_fetchAndCacheAudio` / `_fetchContent` / `_updateState` 逐行相同，仅四类差异：仓储的 `getWordInfo(word, context)` / `getSentenceInfo(sentence)`、正文流方法名（词侧多带 context）、缓存布尔字段名、`WordLearningRequest` / 裸 `String` 的 family 参数。repository 侧两个 `XxxLearningResult` 类同构复制，查缓存 → `resolveXxxAudioPath` → 路径不一致回写 → 组装 Result 的骨架一致。会话资源已下沉 `LearningControllerSession<T>` 且 `repository` 字段已是泛型，为统一预留的接缝已存在，编排层没有跟上。

## Decision

domain 新增统一抽象，词/句各保留一个实现，controller 合并为一个：

- `lib/src/features/learning/domain/learning_query.dart`：`sealed class LearningQuery` 作为统一的 family 参数与仓储请求类型，子类 `WordLearningQuery`（`word` + `context`）与 `SentenceLearningQuery`（`sentence`）；`target` getter 给出音频/持久化键使用的文本主体。两个子类带 `==`/`hashCode`，Riverpod family 以它为键。
- `lib/src/features/learning/domain/learning_repository.dart`：`LearningInfo` 合一两个 Result，字段取中性名 `content` / `hasCachedContent`（另有 `audioUrl` / `hasCachedAudio` / `isFullyCached`）；`abstract interface class LearningRepository` 暴露 `getInfo(query)`、`getContentStream(query)`、`getPronunciationStream(target)`、`saveAudioFile(target, ...)`、`persistAudioPath(target, ...)`。发音与持久化只按键文本寻址，收裸 `String`；正文与信息查询需要完整查询语义，收 `LearningQuery`。
- `WordRepository` / `SentenceRepository` 实现该接口；`getWordInfo` / `getWordExplanationStream` / `getSentenceInfo` / `getSentenceAnalysisStream` 分别更名为 `getInfo` / `getContentStream`，实现内把 `query as XxxLearningQuery` 后取字段。
- `learning_repository_provider.dart` 新增 family provider `learningRepositoryProvider(query)`，按查询类型 `switch` 到词/句仓库；controller 只经 domain 抽象类型引用仓储，选择逻辑留在 data 层。
- 两个 controller 合并为 `lib/src/features/learning/application/learning_controller.dart` 的 `LearningController`（`learningControllerProvider(LearningQuery)`），旧文件与旧 provider 名删除。音频协调器的 `debugLabel` 按查询类型取 `'Word'` / `'Sentence'`。两个 dialog 各改一行调用，无薄壳残留。

保留的真实差异：

- 词侧免费词典 mp3 降级路径（`WordRepository.getPronunciationStream` 先词典后 TTS）原样保留；词典结果的 `cacheByVoice: false` 不变（词侧词典音频不按音色缓存）。
- `saveAudioFile` 两侧签名相同（`cacheByVoice` 形参两侧都有；提案原文误记为仅词侧）。句侧实现多一条 `assert(cacheByVoice)` 不变量——句侧音频永远按音色缓存，合并后原样保留。

## Alternatives considered

**只抽共享基类或部分重叠方法** —— 落败：差异点落在方法签名层，公共接口参数化比"覆盖部分重叠方法"更彻底；半吊子抽取会留下两份壳，复制问题原样保留。

**保持两份** —— 落败：每次改学习流程要双份改动；同构复制已经在扩散（Result 类、stream 消费方式），不合并会继续扩大。

## Consequences

- 词/句两组现有测试全绿且断言不减少：`learning_repository_test.dart` 两组用例迁到 `getInfo` / `LearningInfo` 命名；lifecycle/retry 的 4 组替身（Deferred/Retry × Word/Sentence）合并为 `DeferredLearningRepository` / `RetryLearningRepository` 各一组，覆盖两条路径；`learning_request_cancellation_test` 与 `deep_seek_service_test` 的流调用迁到 `getContentStream`。
- 分层改善：controller 只依赖 domain 的 `LearningRepository` 抽象；application→data 的具体类型依赖（`WordRepository` / `SentenceRepository`）收敛到 provider 选择点。`docs/subsystems/learning.md`、`architecture.md` 数据流、`glossary.md`、`development.md` 的类型名同步更新。
- 合并以迁移前测试为行为基线逐条对照；免费词典降级、取消传播、重试语义均有测试锁定。风险与验收的折入：若词/句差异未来扩大，接口参数化点选在有真实差异的位置，差异真扩大时允许再拆。
- `LearningControllerSession<T>` 泛型参数为 `LearningRepository`；句子继续经 `consumeLearningContentStream` 节流。词侧的逐条结构化更新由[点词释义浮卡](../feature/2026-09-20-word-definition-popover.md)决策持有；共享查询、音频与取消生命周期仍由本笔记持有。

## Dev Note

None.
