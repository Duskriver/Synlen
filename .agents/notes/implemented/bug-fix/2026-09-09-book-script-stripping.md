# Agent Note: 书内脚本供给层剥离

Status: implemented

## Problem

阅读器自己的桥接脚本需要 JavaScript，但书籍携带的脚本不应共享应用桥接能力。旧引擎依赖 iframe sandbox 并在虚拟域供给层剥离脚本；Readium 原生 Navigator 同样启用 JavaScript，不能假定换引擎会自动禁止出版物脚本。

## Decision

安全承诺继续生效，供给路径由 [Readium 引擎决策](../../implemented/architecture/2026-09-20-readium-reader-engine.md)部分取代：`ReadiumPublicationSource` 在打开 EPUB 前调用 `ReadiumEpubPublicationCache`，统一校验 ZIP 并扫描内容文档。TXT 由 `TxtContentService.buildChapterHtml` 整体转义正文后生成 EPUB，不引入书内脚本。

准备层按命名空间的本地名移除脚本、内联事件及可执行嵌入内容，包括脚本 URL、`srcdoc` 和可改写事件或链接的 SVG 动画。XML 外部样式处理指令也移除；自定义 DTD 实体、歧义 ZIP 路径与越界内容引用明确拒绝，避免扫描器与原生阅读器读取不同内容。

无活动内容时沿用原包；需要修改时只重写受影响的内容文档，保留资源路径、OPF 标识符、encryption.xml 与字体字节。缓存键包含源文件 SHA-256 和净化规则版本，规则变化时递增版本。书籍原文件不被修改，派生缓存可删除重建。

## Alternatives considered

**只依赖 WebView 或 SDK 的脚本开关**：阅读器自身需要脚本，Readium 没有已验证的跨平台出版物专属开关。统一准备层给两个平台相同的输入，且可脱离原生视口测试。

**继续用标签扫描保留所有 XHTML 字节**：旧供给层用扫描器避免 XML 解析与重序列化改变实体、自闭合形式。新准备层需同时处理多种活动内容，采用命名空间感知 XML 解析，支持标准 DOCTYPE 与 HTML 具名实体；无须修改时仍保留原包，改写只限必要文档。

**在 Android / iOS 各写一套净化逻辑**：会产生两份资源分类、路径消解和 SVG 规则，难以保证输入一致。

## Consequences

- 依赖书内脚本的交互内容不再工作，不额外提示；脚本增强型 EPUB 不在支持范围。
- 需要净化的 XML 文档可能改变实体表示或属性序列化形式；正文语义与资源身份必须保留，字体混淆所需的标识符和字节不可改写。
- 原有表格与 MathML 分页 CSS 随旧引擎移除，布局兼容由 Readium 及两端设备验收负责；脚本禁用不等于全部 EPUB 排版兼容。

## Testing

`test/features/reader/data/readium_epub_publication_cache_test.dart` 覆盖脚本、事件、嵌入内容、命名空间 SVG 后续正文、实体和包完整性。设备验收仍需确认净化后的正文、图片、长表及字体可读，自有学习桥正常运行。
