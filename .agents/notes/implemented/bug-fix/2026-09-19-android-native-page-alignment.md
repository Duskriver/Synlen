# Agent Note: Android 原生库显式声明 16 KB 对齐

Status: implemented

## Problem

Android 真机启动调试包时弹出 16 KB 兼容性警告。对 APK 内全部 ARM64 库执行 ELF 检查，只有 `libsynlen_rust.so` 的 LOAD 段为 4096 字节，其余库为 16384 或 65536 字节；ZIP 对齐已通过。当前 NDK r27 的默认链接布局没有满足该要求，Flutter 测试和 4 KB 设备上的启动成功无法发现这个缺口。

## Decision

`rust/build.rs` 对 Android 的 `cdylib` 传递 `max-page-size=16384` 与 `common-page-size=16384`，同时约束 LOAD 段和 RELRO 布局。参数属于原生库本身，调试和发布构建共用；其他平台不接收 Android 链接参数。

`tool/verify_android_page_alignment.sh` 检查 APK ZIP 对齐以及全部 ARM64、x86_64 原生库的 LOAD 段。工具缺失、无法解析 ELF、没有 64 位库或对齐不足均失败；发布 APK 校验调用同一脚本，失败时阻止推送和上传。

## Alternatives considered

**仅升级 NDK**：会改变整个原生工具链；显式链接参数可在现有锁定版本下修复，并由产物检查验证结果。

**只在 Cargo 配置中设置 rustflags**：Cargokit 设置 `CARGO_ENCODED_RUSTFLAGS`，可能覆盖配置中的参数；crate 构建脚本直接声明自身动态库的链接要求。

**关闭系统提示或只运行 zipalign**：前者隐藏缺陷，后者只检查 APK 条目位置，不能修复 ELF 的 LOAD 段。

## Consequences

- 对齐检查对修复前的真实 APK 失败，修复后全部库通过；发布脚本测试覆盖 ELF 对齐不足、ZIP 对齐不足及 ELF 解析失败时的阻断。
- 本机 Rust 单元测试验证非 Android 构建不受链接参数影响；Android 覆盖安装和启动验证修复包可运行。4 KB 真机不能替代 16 KB 内核上的完整运行验收。
- 本决策补充[本地与云端共用发布入口](../process/2026-09-17-local-release-with-manual-cloud-fallback.md)的产物检查，其发布顺序与重试规则继续有效。

## References

- [Android 16 KB 页大小与链接参数](https://developer.android.com/guide/practices/page-sizes)
- [Cargo 动态库链接参数](https://doc.rust-lang.org/cargo/reference/build-scripts.html#rustc-link-arg-cdylib)
