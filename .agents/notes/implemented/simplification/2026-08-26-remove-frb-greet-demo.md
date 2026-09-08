# Agent Note: 删除 flutter_rust_bridge 脚手架 demo greet

Status: implemented

## Problem

`rust/src/api/simple.rs` 与其生成物 `lib/src/rust/api/simple.dart` 的 `greet({required String name})` 是 flutter_rust_bridge 初始化时附带的 hello-world demo。`rg '\bgreet\b'` 在业务层（`lib/src/rust/` 之外）零调用；`frb_generated.dart` 里的 `crateApiSimpleGreet` 只服务这一个函数。Rust 桥的真实业务只有 `rust/src/api/epub.rs`（EPUB 中央目录缓存与解压，`readEpubFile` 有生产调用）。

## Decision

删除 `rust/src/api/simple.rs`（同步 `rust/src/api/mod.rs` 的模块声明），重跑 flutter_rust_bridge codegen 刷新 `lib/src/rust/` 生成物，确认 `cargo check` 与 `flutter analyze` 通过。

## Alternatives considered

**保留 demo** —— 放弃：每次升级 FRB 版本重新生成都会带着它；对读者是噪音，分不清 FFI 桥里哪些是示例、哪些是生产。

## Consequences

- `rg '\bgreet\b|crateApiSimpleGreet' lib rust` 清零。
- 后续新增 Rust 接口直接放 `rust/src/api/` 的业务模块，不再有示例文件干扰。
- 代价：FRB codegen 需要 Rust 工具链与 `flutter_rust_bridge_codegen` 可执行；环境不就绪时只能保留提案，不手改生成物。
