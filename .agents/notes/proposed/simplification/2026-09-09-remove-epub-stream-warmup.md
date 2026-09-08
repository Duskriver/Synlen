# Agent Note: 删除 EpubStreamService.warmUp 空实现

Status: proposed

## Problem

`lib/src/features/reader/data/services/epub_stream_service.dart` 的 `warmUp()` 是 `Future<void> warmUp() async {}`——空实现。唯一调用点 `epub_stream_service_provider.dart` 在构造服务时调用它，同样什么也不做。调用方与实现都是零行为，却让读者以为打开书籍前存在一次预热（解压、isolate 或缓存预取）。

## Proposal

删除 `warmUp` 方法与 provider 中的调用行。`openBook` 仍是打开书籍的唯一入口，负责设置当前书路径并等待 Rust 侧加载。重跑 `flutter analyze` 与 `test/features/reader/` 下的测试。

## Alternatives considered

**保留空方法，等以后真的做预热** —— 放弃：没有证据表明打开延迟是瓶颈；真的需要预热时，预热逻辑属于 `openBook` 的实现细节，不该由调用方显式触发一个空方法。

**保留方法但让它真的预热** —— 放弃：会在每次 provider 构造时引入不必要的 IO，且当前没有任何调用方需要它。

## Acceptance criteria

- `rg 'warmUp' lib` 清零。
- `flutter analyze` 零 error 零 warning；`flutter test test/features/reader/` 全绿。
- 手测一次打开书籍：首屏渲染与翻页不受影响。

## Risks

纯机械删除，无行为变化。风险只有并行分支对同一签名的冲突；若有分支仍调用 `warmUp`，rebase 时删除该调用即可。
