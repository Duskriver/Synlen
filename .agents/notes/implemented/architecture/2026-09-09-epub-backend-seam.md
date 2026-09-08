# Agent Note: EPUB 后端抽出 EpubBackend 接口，切书关闭旧缓存

Status: implemented

## Problem

`EpubStreamService` 直接调用 flutter_rust_bridge 的静态 API，切书时只记录新路径、从不关闭上一本的 Rust 缓存条目——同一会话内连续打开多本书会累积缓存（`docs/subsystems/rust.md` 已记为待办，而 `rust.md` 的流程小节却写着"切换书籍时先关掉旧缓存"，文档与实现不符）。静态调用也让这段切书逻辑无法脱离 FFI 单测。

## Decision

- `EpubBackend`（`data/services/epub_backend.dart`）：`load` / `readFile` / `close` 三个方法的接口；生产实现 `RustEpubBackend` 直接转调生成的 API，测试用 fake。
- `EpubStreamService` 构造时注入 backend，默认 `RustEpubBackend()`；`_doOpenBook` 在加载新书前先 `close` 上一本（同一路径不重复关闭），`dispose` 关闭当前书。

## Alternatives considered

**只加一行 close，不抽接口** —— 放弃：没有 fake 就没法验证"切书关闭上一本、同书不重复加载、并发只加载一次"，而这三条正是这段逻辑的全部价值。

**把 backend 做成 provider 注入** —— 放弃：服务本身已经是 provider（keepAlive），backend 只是它的实现细节；构造参数默认值足够，测试直接传 fake。

**在 Rust 侧加容量上限自动淘汰** —— 放弃：跨语言改动成本高，且"谁打开谁关闭"的契约在 Dart 侧已经足够清晰。

## Consequences

- 切书不再累积 Rust 缓存条目；`reader.md` 的待办与 `rust.md` 的流程描述现在一致。
- `EpubStreamService` 的切书与释放逻辑有 6 个单元测试覆盖（`epub_stream_service_test.dart`）。
- 行为变化一处：打开新书时会先关闭上一本——这正是待办要求的修复。
