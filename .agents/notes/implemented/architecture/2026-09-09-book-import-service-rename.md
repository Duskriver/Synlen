# Agent Note: EpubImportService 改名为 BookImportService

Status: implemented

## Problem

`EpubImportService` 按 `BookFormat` 分发解析与落盘，TXT 走的是它的分支，名字却写着 Epub——新格式接入时容易把 TXT 逻辑放到别处。这是[格式中立命名提案](../../proposed/architecture/2026-09-09-format-neutral-book-naming.md)的第一步。

## Decision

类名 `EpubImportService` → `BookImportService`，文件与 provider 同步改名（`book_import_service.dart` / `book_import_service_provider.dart` / `bookImportServiceProvider`）。文档与实现笔记里的现状描述一并更新。

## Alternatives considered

**保留旧名，只改注释** —— 放弃：注释不改变调用方看到的名字。

**与原生通道方法名、虚拟域一起改** —— 放弃：跨语言契约与生成物混在一个提交里无法二分定位；提案要求分三步。

## Consequences

- `rg 'EpubImportService|epub_import_service' lib test docs` 为空（提案笔记除外，它记录问题）。
- 纯改名，行为不变；`EpubStreamService` / `EpubZipParser` / `EpubTheme` 仍保留 Epub 名——它们只服务 EPUB。
- 提案的第二步（原生通道方法名）与第三步（`epub://` 虚拟域）待做。
