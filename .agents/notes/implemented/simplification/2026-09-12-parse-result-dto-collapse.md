# Agent Note: 消灭 ParseResult 逐字段抄写

Status: implemented

## Problem

`ParseResult`（原 `lib/src/features/library/data/services/epub_import_workers.dart`）是 `EpubZipParseResult`（`lib/src/features/library/data/parsers/epub_zip_parser.dart`）13 个字段的无差异副本，仅多一个 `format` 字段。`ImportWorkers.parseEpub` 对解析结果逐字段抄写 15 行构造它；`parseTxt` 把 TXT 结果塞进同一结构、大半字段填空串。全库构造点就这三处。两个同构类并存意味着改解析结果字段要同步改三处。

## Decision

`EpubZipParseResult` 成为唯一解析结果类型：它直接携带 `format` 字段（类型 `BookFormat`，构造默认 `BookFormat.epub`）。`ParseResult` 类与两处逐字段抄写删除：

- `ImportWorkers.parseEpub` 直接返回 `EpubZipParser.parseFromFile` 的结果，借助 `format` 默认值无需任何转换。
- `ImportWorkers.parseTxt` 构造 `EpubZipParseResult`，空串 / null / 空列表字段的填法与合并前逐字节相同（TXT 无对应信息：`author=''`、`authors=[]`、`subjects=[]`、`coverHref=null`、`opfRootPath=''`、`epubVersion=''`、`manifestItems=[]`、`readDirection=0`，`format: BookFormat.txt`）。
- `BookImportService` 的签名引用从 `ParseResult` 改为 `EpubZipParseResult`（`importBook` 局部变量、`_parseAndExtract`、`_createEntities` 共三处），并直接 import parser 文件。
- isolate 边界不变：`compute()` 传参 / 返回值仍是 `ParseParams` 与 `Either<LibraryException, …>`，返回值经 SendPort 直传 `EpubZipParseResult` 无障碍。

## Alternatives considered

**TXT 产出独立结果类型（第二阶段）** —— 否决：消费方 `BookImportService._createEntities` 无条件读全部字段建 `BookManifest`，拆类型等于把空串从数据字段挪成分支逻辑，收益不抵复杂度。若未来消费方按 `format` 分支处理，可重新评估。

**保持 DTO 分层（parser 结果不跨 isolate 边界直传）** —— 落败：`compute()` 跨 isolate 传 Dart 对象无需 DTO 转换，这层"parser 结果不直传"的约束没有实际约束力，却付出逐字段抄写的成本。

**只给 `ParseResult` 加字段、保留两份类** —— 落败：同构双类仍在，抄写只是从构造点挪到字段同步上，问题原样保留。

## Consequences

- TXT 路径的空串字段语义已落库（`BookImportService._createEntities` 建 `BookManifest`），合并后这些落库值一字节不变；`epub_zip_parser.dart` 的 dartdoc 与该处注释记录了这条约束，改动字段填法前必须先确认消费方。
- 全库 rg 无 `ParseResult`（parser 结果类型只剩 `EpubZipParseResult` 与 TXT parser 自己的 `TxtBookParseResult`）。
- 解析结果加字段只需改 `EpubZipParseResult` 与两个构造点（parser 本体 + `parseTxt` 的 TXT 分支）。
