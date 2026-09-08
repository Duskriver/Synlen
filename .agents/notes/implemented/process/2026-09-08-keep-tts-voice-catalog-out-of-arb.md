# Agent Note: TTS 音色目录与 LLM 提示词不迁入 ARB

Status: implemented

## Problem

清理 UI 硬编码中文时，`lib/src/features/learning/domain/aliyun_tts_voice.dart` 有 51 行中文（49 个音色的中文名与音色描述），`deep_seek_service.dart` 有 6 行中文（发给模型的提示词）。如果按"用户可见文案一律走 l10n"机械处理，它们都要进 ARB。

## Decision

这两类文本**留在代码里**：

- `AliyunTtsVoice` 的名称与描述是**产品目录数据**（人名、方言地名、人设描述），随服务商音色表变化，不是界面文案；全部迁 ARB 需要 98 个键，成本远大于收益。
- `deep_seek_service.dart` 的提示词是**机器消费**的输入，不面向用户。

界面文案本身（设置页、学习弹窗、错误提示）仍一律走 ARB，错误码到文案的映射在展示层统一做。

## Alternatives considered

**全部迁入 ARB** —— 放弃：音色表是数据不是文案，键的数量与维护成本（每次服务商调整音色都要改两个 ARB 文件）远超收益。

**把音色表挪到 JSON 资源文件** —— 放弃：会引入一套没有第二使用者的加载与解析代码，收益仅是把常量换个位置。

## Consequences

- 判断标准固化下来：**面向用户的界面文案走 ARB；产品目录数据与机器消费的提示词留在代码**。
- 新增音色直接改 `aliyun_tts_voice.dart`；新增界面文案必须走 ARB，见 [adding-an-l10n-string](../../../../docs/cookbook/adding-an-l10n-string.md)。
