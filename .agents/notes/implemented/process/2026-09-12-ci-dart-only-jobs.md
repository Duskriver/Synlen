# Agent Note: CI 纯 Dart job 改用 setup-dart

Status: implemented

## Problem

CI 的 docs job（`.github/workflows/flutter_ci.yml`）为运行 `tool/doc_gates.dart`（只 import `dart:convert` 与 `dart:io`）安装完整 Flutter SDK 并执行 `flutter pub get`；web-assets job 的 `flutter pub get` 只为 `dart run tool/build_web_assets.dart`（只 import `dart:io`）。这些是纯 Dart 脚本，Flutter 安装与 pub get 是纯成本：拖长 job 时长，也扩大 CI 的失败面。

## Decision

- docs 与 web-assets job 改用 `dart-lang/setup-dart`（固定到 commit SHA，尾注标出版本，与其他 action 的 pin 风格一致），去掉 Flutter 安装与 pub get 步骤；job 内其余步骤（npm ci、typecheck、Playwright、漂移检测）原样保留。
- setup-dart 的 `sdk: '3.12.2'` 与 Flutter 3.44.9 自带 Dart 锁步（依据：`flutter --version` 本地验证 Flutter 3.44.9 → Tools · Dart 3.12.2，与[工具链锁步](2026-08-11-pin-toolchain-and-dependency-ceiling.md)记录一致）。
- 两个脚本以裸 `dart tool/xxx.dart` 运行（无 package import 时与 `dart run` 等价，且仓库无 `.dart_tool` 时更稳），头注释声明"纯 Dart 脚本，无 package 依赖，CI 用 setup-dart 直接运行"。
- `build_release.yml` 的 quality-gates job 有意保留 Flutter 环境跑 doc_gates 与 build_web_assets：那里本来就要装 Flutter 做 format/analyze/test，两个脚本是搭便车而非浪费，不做统一。

## Alternatives considered

**保持统一 Flutter 环境** —— 落败：CI 时长与失败面是纯成本，脚本本身无 Flutter 依赖。

**让脚本依赖 Flutter** —— 落败：反向增加依赖，两个脚本目前与未来都没有理由触碰 Flutter。

## Consequences

- 脚本头注释把"纯 Dart、setup-dart 运行"的约定写在依赖旁边：未来脚本引入 package 依赖时，改脚本的人最先看到它，需同步把对应 CI job 改回 Flutter 环境。
- `sdk: '3.12.2'` 与 flutter-version `3.44.9` 锁步：升级 Flutter 时必须同步改两个 job 的 setup-dart 版本（Flutter 自带 Dart 版本以 `flutter --version` 的 Tools 行为准）。
- `build_release.yml` 不要"顺手统一"成 setup-dart：quality-gates 装 Flutter 是必要的，脚本在那里搭便车零成本。
- 验收对照：两个 job 的 CI 日志不再有 Flutter 安装步骤，job 时长应低于改动前的 CI 记录。

## Dev Note

None.
