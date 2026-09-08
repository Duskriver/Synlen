# Agent Note: 格式中立命名（Epub* 同时服务 EPUB 与 TXT）

Status: proposed

## Problem

若干以 `Epub` 命名的类型与通道方法实际同时服务 EPUB 与 TXT：

- `EpubImportService`（`library/data/services/`）按 `BookFormat` 分发解析与落盘，TXT 走的是它的分支（`docs/subsystems/library.md` 待办）。
- `EpubWebViewHandler`（`reader/application/`）与虚拟域 `epub://` 同时供给 EPUB 与 TXT 章节（`docs/subsystems/reader.md` 待办）；`epub://` 在 7 个 Dart 文件与 1 个 TS 文件里出现。
- 原生选择器的通道方法 `pickEpubFiles` / `pickEpubFolder` / `isEpubFile` 已按 `BookFormat` 放开 TXT，却仍叫 Epub（Android `NativePickerPlugin.kt`、iOS `NativePickerPlugin.swift`、Dart `NativeFilePicker`）。

`EpubStreamService`、`EpubZipParser`、`EpubTheme` 等确实只服务 EPUB，**不在本提案范围内**。

## Proposal

按"改动面从窄到宽"分三步，每步一次提交、独立验证：

1. **Dart 类型名**：`EpubImportService` → `BookImportService`、`EpubWebViewHandler` → `BookWebViewHandler`（含 provider、文件与测试重命名）——已交付。纯 Dart，无跨语言契约变化。
2. **原生通道方法名**：`pickEpubFiles` / `pickEpubFolder` / `isEpubFile` → `pickBookFiles` / `pickBookFolder` / `isBookFile`（已交付，Kotlin、Swift 与 Dart 三处同批改齐）。
3. **虚拟域**：`epub://` → `book://`，同批改 `EpubWebViewHandler.virtualScheme`、`book_session`、`txt_content_service`、`link_handling_mixin`、`font_manager_notifier` 与 `web_assets/controller.js/renderer/theme_manager.ts`，并重跑 `dart run tool/build_web_assets.dart` 生成 `lib/src/web/web_assets.dart`。

## Alternatives considered

**只改 Dart，不动通道与虚拟域** —— 放弃：通道方法与虚拟域才是"名字撒谎"最容易被外部（原生代码、JS 资源）读到的地方，半改会留下两种命名并存。

**一次性全仓库改名** —— 放弃：跨语言契约与生成物混在一个提交里，出问题时无法二分定位；分三步各自可回滚。

**不改，接受命名与职责不符** —— 放弃：新格式（如 MOBI）接入时，`Epub*` 命名的分发点会继续被误认为 EPUB 专属，诱使后来者把 TXT 逻辑放到别处。

## Acceptance criteria

- `rg 'EpubImportService|EpubWebViewHandler|pickEpubFiles|pickEpubFolder|isEpubFile' lib android ios web_assets --glob '!node_modules'` 为空。
- `rg 'epub://' lib web_assets --glob '!node_modules'` 为空，且 `lib/src/web/web_assets.dart` 与 `web_assets/` 源一致（构建脚本无漂移）。
- `EpubStreamService` / `EpubZipParser` / `EpubTheme` 保持原名。
- 全量 `flutter test` 绿、`flutter analyze` 零 issue、分层门禁通过；真机手测：EPUB 与 TXT 各导入一次并翻章、字体注入、外链跳转。

## Risks

- 通道方法名是跨语言契约：漏改一侧会在运行时报 `MissingPluginException`，只能靠真机冒烟发现——三步里必须把原生改动与 Dart 改动放在同一次提交。
- 虚拟域改名会同时影响注入的 CSS 与 JS 资源引用，需重跑资源构建并核对生成物。
- 若将来出现第二种内容供给后端，`BookWebViewHandler` 这个名字仍然成立；但 `BookSession` 已有同名概念，命名时避免与它混淆（`BookContentHandler` 是备选）。
