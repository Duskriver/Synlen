# Agent Note: AI 服务密钥由用户自配（BYOK）

Status: implemented

## Problem

点词释义、句子分析与 TTS 都需要第三方密钥（DeepSeek、阿里云 DashScope）。早期做法是构建时经 `--dart-define` 注入，或在 CI 用 secrets 打进包：开源分发后，任何一次构建都碰得到密钥注入路径，源码、CI 配置与安装包同时成为泄露面；用户也没法换成自己的额度。

## Decision

密钥由用户在「设置 → AI 服务」自填，只存设备安全存储：

- `FlutterSecureStorage`（Android Keystore / iOS Keychain）是唯一存放处，键为 `api_key_deepseek` 与 `api_key_aliyun_tts`。
- 读取只在运行时发生：学习模块经 settings 的 `ApiKeyNotifier` 取密钥，未配置时抛 `noDeepSeekApiKey` / `noAliyunTtsApiKey`，不向第三方发出请求。
- 源码、构建配置、CI 与安装包不含任何密钥，发布链路与密钥无关。
- `ApiKeyNotifier` 的写入串行化，避免并发覆盖。

## Alternatives considered

**继续用 `--dart-define` 注入** —— 放弃：密钥要经构建环境与 CI secrets，开源后无法保证 fork 不会把自己的密钥打进包；用户也无法替换成自己的额度。

**内置一把项目密钥** —— 放弃：密钥进源码或安装包，配额与泄露都不可控。

**自建服务端代理** —— 放弃：需要一个常驻服务与账号体系，与"离线优先、无后端"的定位冲突。

## Consequences

- 用户必须自配密钥才能用学习功能；未配置时其余功能不受影响，说明见 [AI 服务密钥](../../../../docs/user/guide/ai-service-keys.md)。
- 密钥不进日志：内部细节只入 `appLogger`，用户可读消息走 l10n。
- 发布流水线只持有签名与分发凭据，见[更新分发走 Gitee](../process/2026-09-17-release-distribution-via-gitee.md)。
