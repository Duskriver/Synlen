# Agent Note: TXT 内容供给经宿主 application 适配 spine 来源

Status: implemented

## Problem

`reader/data/services/txt_content_service.dart` 直接依赖 `library/data` 的 `BookManifestRepository` 与两个 parser：内容供给要按 fileHash 取 spine，仓库是现成入口；`chapterIndexFromPath` 与 `isHeadingLine` 两条纯规则也住在 library 的 parser 里，阅读时只能反过来 import。

这违反[组合面决策](2026-09-08-composition-surface-cross-feature.md)的「宿主对能力模块」条款（宿主 application 只依赖能力模块的 application 查询接口），也让两个 feature 的 data 层互相绑定。

## Decision

- reader 的 data 层定义自己需要的 seam：`TxtSpineSource`（`spineFor(fileHash)` 一个方法），`TxtContentService` 只依赖它。
- 生产实现在 `reader/application/txt_content_service_provider.dart`：用 `library/application` 的 `BookQueries.findManifest` 适配；provider 随装配一起留在 application。
- TXT 的两条纯规则搬到 `library/domain`：虚拟章节路径契约（`txt_chapter_path.dart`）与标题行判定（`txt_heading.dart`）。切分算法留在 `library/data`。

## Alternatives considered

**让 `TxtContentService` 直接吃 `BookQueries`** —— 放弃：那会把跨 feature 的 application 依赖塞进 reader 的 data 层；宿主 application 才是允许跨 feature 的层。

**在 library 侧为 reader 造接口** —— 放弃：seam 放在调用方需要它的位置；library 已有的 `BookQueries` 就是能力入口，再包一层只是转发。

**把切分算法整体搬到 domain** —— 放弃：切分含体积分割等实现细节，reader 不需要；只搬阅读时复用的两条规则。

## Consequences

- reader 的 data 层不再有跨 feature 的 data 依赖；分层门禁的跨 feature 边表中，reader → library 只剩 `application` 与 `domain`。
- `TxtSpineSource` 有两种实现（`BookQueriesTxtSpineSource` 与测试 fake），不是假 seam。
- `TxtBookParser.chapterPathPrefix` / `chapterIndexFromPath` 与 `TxtChapterSplitter.isHeadingLine` 的调用方改为 domain 函数，对应测试迁到 `test/features/library/domain/`。
