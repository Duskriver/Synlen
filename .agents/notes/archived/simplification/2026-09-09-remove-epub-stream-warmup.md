# Agent Note: 删除 EpubStreamService.warmUp 空实现

Status: implemented
Archived: 2026-09-20

## Problem

`lib/src/features/reader/data/services/epub_stream_service.dart` 的 `warmUp()` 是 `Future<void> warmUp() async {}`——空实现。唯一调用点 `epub_stream_service_provider.dart` 在构造服务时调用它，同样什么也不做。调用方与实现都是零行为，却让读者以为打开书籍前存在一次预热（解压、isolate 或缓存预取）。

## Decision

`EpubStreamService` 不再有 `warmUp`；`openBook` 是打开书籍的唯一入口，负责设置当前书路径并等待 Rust 侧加载。provider 只构造服务并注册 `ref.onDispose`。

## Alternatives considered

**保留空方法，等以后真的做预热** —— 放弃：没有证据表明打开延迟是瓶颈；真的需要预热时，预热逻辑属于 `openBook` 的实现细节，不该由调用方显式触发一个空方法。

**保留方法但让它真的预热** —— 放弃：会在每次 provider 构造时引入不必要的 IO，且当前没有任何调用方需要它。

## Consequences

纯机械删除，无行为变化。`rg 'warmUp' lib` 清零；reader 测试全绿。
