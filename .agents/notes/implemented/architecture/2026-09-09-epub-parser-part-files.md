# Agent Note: EPUB 解析器按职责拆成 part 文件

Status: implemented

## Problem

`epub_zip_parser.dart` 880 行，一个类里塞着四类互不相干的工作：ZIP 入口与 OPF 编排、OPF 元数据与封面回退链、NCX / NAV 目录解析、相对路径归一化。改任意一条规则都要在近千行里定位，模块参考页也只能把它记成"超 400 行文件"。

## Decision

`EpubZipParser` 保留入口与编排（`parseFromFile` / `parseFromBytes` / `parseFromArchive` / `_findOpfPath` / `_parseOpf`），其余按职责拆到三个 part 文件：

- `epub_opf_metadata.dart`：`_parseMetadata`、`_parseGuide`、`_extractFirstImageFromHtml`、`_MetadataResult`、`_GuideItem`。
- `epub_toc_parser.dart`：`_parseNcx`、`_parseNavPoints`、`_parseNav`、`_parseNavListItems`、`_parseSpineAsChapters`、`_containsWholeWord`。
- `epub_path_resolver.dart`：`_resolveHref`、`_normalizePath`、`_resolveRelativePath`、`_generateRelativePath`、`_isWellImageFile`。

被拆出的方法从类的静态方法降为库内私有函数，调用点写法不变（类内原本就是非限定调用）。`_decodeString` 同样降为顶层函数，供各 part 共用。

## Alternatives considered

**拆成独立的公开类（`EpubTocParser` 等）** —— 放弃：这些步骤只服务一次解析，拆成公开类型会造出没有第二个调用方的接口面；先按文件分离职责，等真的出现第二种用法再提接口。

**保持单文件、只加分区注释** —— 放弃：注释不减少定位成本，门禁与参考页也仍把它记为超限文件。

**用 extension 挂回 `EpubZipParser`** —— 放弃：静态成员不能放进 extension，且会让"属于解析器"的错觉更深。

## Consequences

- 解析器由 1 个 880 行文件变成 4 个不超过 362 行的文件；模块参考页不再把它列为超限文件。
- part 共享同一个库，私有成员仍不可跨库访问，拆分不改变封装边界。
- 行为不变，`test/epub_parser_test.dart` 的 19 组用例原样通过。
