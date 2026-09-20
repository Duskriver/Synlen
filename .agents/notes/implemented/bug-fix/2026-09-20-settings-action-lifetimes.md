# Agent Note: 设置操作持有用例与服务的异步生命周期

Status: implemented

## Problem

缓存清理和密钥检查都通过按钮临时读取自动释放的 provider。清理等待文件操作时，用例被释放，后续读取学习清理服务抛错，按钮持续忙碌；密钥检查的 HTTP 服务无人订阅，在响应前关闭连接，把有效密钥误判为不可达。直接替换服务值的测试没有执行资源释放回调，无法发现这些问题。

## Decision

`CleanCacheTile` 与密钥检查入口订阅用例的 `AsyncValue`，用例在 `build()` 中订阅服务。状态承载运行进度与结果，阻止同一操作重复执行；缓存清理在 application 捕获失败并记录日志，界面展示本地化提示并恢复按钮。密钥检查直接使用设置页已加载的配置值。

生命周期由页面订阅决定。离开页面后释放无人使用的服务，异步结果通过 `ref.mounted` 检查后才可更新状态；清理在阶段间检查存活状态，退出后不启动下一阶段。再次进入页面会创建新的用例与所需服务。

这项修复沿用[更新检查持有服务的决策](../architecture/2026-09-09-update-flow-out-of-presentation.md)，扩展到同属设置页的两个独立操作；更新检查的决策仍保留其检查、下载和安装边界。

## Alternatives considered

**将用例和服务改为永久存活**：会在退出设置页后保留 HTTP 连接，无法表达页面结束后的释放边界。

**仅在按钮中订阅用例**：服务仍只有一次 `read`，HTTP 客户端依然可能在等待响应时关闭；用例必须同时订阅它依赖的服务。

**在界面捕获清理异常并恢复按钮**：没有修复用例被提前释放的原因，并将业务失败处理留在 presentation，无法验证 application 的完整状态流。

## Consequences

- 清理并非事务：失败或退出时，已完成的删除保留；重试继续清理仍存在的可重建缓存。
- 缓存清理与密钥检查的调用方必须持有用例订阅，和更新检查保持一致。
- [设置操作 widget 测试](../../../../test/features/settings/settings_actions_lifecycle_test.dart)通过真实按钮与延迟服务覆盖成功、失败后重试、退出及再次进入；[缓存清理测试](../../../../test/features/settings/application/cache_cleanup_test.dart)和[密钥检查测试](../../../../test/features/settings/application/deep_seek_connectivity_test.dart)覆盖重复调用、阶段计数、错误状态与退出后的迟到结果。服务替身使用 `overrideWith` 保留自动释放回调。
