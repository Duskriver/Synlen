# Agent Note: 原生选择器通道方法改为 Book 命名

Status: implemented

## Problem

通道方法 `pickEpubFiles` / `pickEpubFolder` / `isEpubFile` 早已按 `BookFormat` 放开 TXT，名字却仍写着 Epub。这是[格式中立命名提案](../../proposed/architecture/2026-09-09-format-neutral-book-naming.md)的第二步。

## Decision

三处同批改名：Android `NativePickerPlugin.kt`、iOS `NativePickerPlugin.swift`、Dart `native_file_picker.dart`（`invokeMethod` 的字符串参数）。通道方法名是跨语言契约，任何一侧漏改都只在运行时暴露。

## Alternatives considered

**只改 Dart 字符串** —— 放弃：原生 switch 分支不认新名字，调用直接失败。

**保留旧名加注释** —— 放弃：外部（原生代码）看到的名字仍是误导。

## Consequences

- `rg 'pickEpubFiles|pickEpubFolder|isEpubFile' lib android ios` 为空。
- Dart 侧改名经 analyze 与全量测试验证；原生侧改名**只能靠真机冒烟验证**（导入 EPUB 与 TXT 各一次），CI 的 Kotlin/Swift 编译任务覆盖不了通道字符串匹配。
- 提案第三步（`epub://` 虚拟域）待做。
