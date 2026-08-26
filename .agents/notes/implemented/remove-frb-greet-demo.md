# 删除 flutter_rust_bridge 脚手架 demo:greet

Status: implemented

## Problem

- `rust/src/api/simple.rs` 与其生成物 `lib/src/rust/api/simple.dart` 的 `greet({required String name})` 是 flutter_rust_bridge 初始化时附带的 hello-world demo。
- `rg '\bgreet\b'` 业务层(`lib/src/rust/` 之外)零调用;`frb_generated.dart` 中的 `crateApiSimpleGreet` 只服务这一函数。Rust 桥的真实业务只有 `rust/src/api/epub.rs`(EPUB 中央目录缓存与解压,`readEpubFile` 有生产调用)。

## Proposal

- 删除 `rust/src/api/simple.rs`(同步 `rust/src/api/mod.rs` 的模块声明)。
- 重跑 flutter_rust_bridge codegen,刷新 `lib/src/rust/` 下生成物(`simple.dart`、`frb_generated.dart` 中相关代码随之消失)。
- 确认 `cargo check` 与 Flutter 侧 `flutter analyze` 通过。

## Why not keep it

保留成本:每次升级 FRB 版本重新生成时都会带着这个 demo;对读者是噪音(分不清 FFI 桥哪些是示例哪些是生产)。删除风险:零调用方;不触碰 `epub.rs`(ADR 认定的性能决策)。

## Acceptance criteria

- `rg '\bgreet\b|crateApiSimpleGreet' lib rust` 清零。
- `cargo check`(rust/)与 `flutter analyze` 通过;全量 `flutter test` 全绿。

## Risks

- FRB codegen 需 Rust 工具链与 `flutter_rust_bridge_codegen` 可执行;若本地不可用则保留本提案待环境就绪,不手改生成物。
