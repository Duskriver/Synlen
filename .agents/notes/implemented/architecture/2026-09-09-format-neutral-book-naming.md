# Agent Note: 格式中立命名（Epub* 同时服务 EPUB 与 TXT）

Status: implemented

## Problem

若干以 `Epub` 命名的类型与通道方法实际同时服务 EPUB 与 TXT：`EpubImportService` 按 `BookFormat` 分发解析与落盘；`EpubWebViewHandler` 与虚拟域 `epub://` 同时供给两种格式的章节；原生选择器的通道方法 `pickEpubFiles` / `pickEpubFolder` / `isEpubFile` 已按格式放开 TXT，名字却仍写着 Epub。

## Decision

最初按改动面从窄到宽分三步改名：

1. **Dart 类型名**：`EpubImportService` → `BookImportService`、`EpubWebViewHandler` → `BookWebViewHandler`（含文件、provider 与测试重命名）。
2. **原生通道方法名**：`pickEpubFiles` / `pickEpubFolder` / `isEpubFile` → `pickBookFiles` / `pickBookFolder` / `isBookFile`，Kotlin、Swift 与 Dart 三处同批（通道方法名是跨语言契约）。
3. **虚拟域**：`epub://` → `book://`，同批改 `virtualScheme`、Dart 字面量、`theme_manager.ts` 的字体 URL 与 l10n 的 ARB 描述，并重跑 `build_web_assets.dart` 与 `flutter gen-l10n`。

[Readium 引擎决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)已删除虚拟域、`BookWebViewHandler` 与 `EpubStreamService`。导入服务和原生选择器的格式中立命名继续生效；`EpubZipParser` 仍专门解析 EPUB，`EpubTheme` 是 EPUB 与 TXT 共用的阅读配色类型。

## Alternatives considered

**只改 Dart，不动通道与虚拟域** —— 放弃：通道方法与虚拟域才是名字最容易误导外部（原生代码、JS 资源）的地方，半改会留下两种命名并存。

**一次性全仓库改名** —— 放弃：跨语言契约与生成物混在一个提交里，出问题时无法二分定位。

**不改，接受命名与职责不符** —— 放弃：新格式接入时，`Epub*` 命名的分发点会继续被误认为 EPUB 专属。

## Consequences

- `rg 'EpubImportService|EpubWebViewHandler|pickEpubFiles|pickEpubFolder|isEpubFile' lib android ios web_assets` 与 `rg 'epub://' lib web_assets` 均为空。

- 通道字符串匹配由静态核对保证：通道名在 Dart / Kotlin / Swift 三处一致，Dart 调用的 8 个方法名在各自平台都有实现（`getDisplayName` 限 Android、`fetchIosFile` / `releaseIosAccess` 限 iOS，调用处都有平台判断）。
- 真机冒烟验的是运行时行为：导入 EPUB 与 TXT 各一次、翻章、字体注入、外链跳转。
