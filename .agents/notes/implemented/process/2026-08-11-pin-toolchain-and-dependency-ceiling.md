# Agent Note: 工具链锁在 Flutter 3.44.9 生态

Status: implemented

## Problem

2026-08-11 升级到最新稳定版时撞上上游生态锁：Flutter 3.44 的 `test_api 0.7.11` 把 `analyzer` 上限压在 12，而 riverpod generator 4.0.6+ 与 drift_dev 2.34.5+ 都需要 analyzer 13。盲目跟随最新版本会让 codegen 直接跑不起来，且"本地能过、CI 不过"的版本漂移会常态化。

## Decision

- 工具链固定在验证过的组合：Flutter 3.44.9 stable、Dart 3.12.2、Rust 1.97.1（`rust-toolchain.toml` 固定 channel 与 minimal profile）。
- `pubspec.yaml` 只声明下限（`sdk: ^3.10.8`、`flutter: ">=3.38.0"`），CI 用 `flutter-version: '3.44.9'` 固定实际构建版本。
- 依赖锁在 analyzer 12 可解的版本：`flutter_riverpod ^3.3.2`、`riverpod_annotation 4.0.3`；升级 generator 与 drift_dev 要等 Flutter 解锁 analyzer 13，与升级同批验证。
- 升级工具链是独立改动，跑全量 `flutter test` 与 `cargo test` 后再提交。

## Alternatives considered

**跟随 latest stable** —— 放弃：analyzer 13 未解锁，codegen 无法运行。

**不固定版本、各人自选** —— 放弃：版本漂移会让"本地能过、CI 不过"变成常态。

**用 `dependency_overrides` 强拉 analyzer 13** —— 放弃：绕过 Flutter SDK 的传递依赖约束，会破坏 `flutter test` 自身。

## Consequences

- 升级 Flutter 前先确认 `analyzer` 上限，再决定 generator 与 drift_dev 的版本。
- 需要 Flutter ≥ 3.38.0、Dart ≥ 3.10.8，见 [开发](../../../../docs/development.md#环境)。
