# Agent Note: 补 TTS 音色持久化的单元测试

Status: implemented

## Problem

`docs/subsystems/settings.md` 记着设置模块只有 AI 密钥与连通性有测试；`TtsVoiceNotifier` 的读取回退、未知参数回退与写入持久化都没有覆盖，而 learning 的仓库 provider 直接依赖它——音色错了，学习缓存会按错误的音色键读写。

## Decision

补 `test/features/settings/application/tts_voice_notifier_test.dart`：未持久化回退默认音色、读取已持久化音色、未知参数回退默认、`setVoice` 同时写 prefs 与更新状态。用 `SharedPreferences.setMockInitialValues` 与 `sharedPreferencesProvider` 覆盖，与 `reader_settings_notifier_test` 同形。

## Alternatives considered

**先测主题与字体** —— 放弃：音色是 learning 缓存键的一部分，错了会污染缓存；优先测它。

**顺带测 `cache_cleanup`** —— 放弃：它需要两个服务 mock，等整理组合面测试时一起做。

## Consequences

- 设置模块的测试缺口清单少一项（音色）。
- 音色的持久化格式（`voiceParam`）被测试钉住，改枚举时能立刻发现迁移问题。
