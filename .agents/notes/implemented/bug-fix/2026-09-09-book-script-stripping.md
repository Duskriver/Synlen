# Agent Note: 书内脚本供给层剥离

Status: implemented

## Problem

书籍 XHTML 经 `book://` 虚拟域供进 InAppWebView，`reader_webview.dart` 的 `javaScriptEnabled: true` 是阅读器自身脚本（controller.js 注入、骨架配置）所必需，无法全局关闭。渲染骨架的三 iframe 带 `sandbox="allow-same-origin"`（无 `allow-scripts`），理论上已禁止书内脚本执行，但这把安全性完全押在 WebView 对 sandbox 的强制力上：Android System WebView 版本碎片化，旧实现存在 sandbox 绕过与不一致的历史；一旦失效，恶意或失控的书籍脚本与阅读器同域（`book://localhost`），可读同源任意书内容。

## Decision

在供给层剥离，方案 (a)：`BookWebViewHandler._readFileFromEpub` 供给 XHTML/HTML/XML/SVG 前调用纯函数 `sanitizeBookXhtml`（`lib/src/features/reader/domain/xhtml_sanitizer.dart`），剥掉 `<script>` 元素（含 SVG 内、带命名空间前缀如 `<svg:script>`、大小写混杂、自闭合形态）与所有元素上的 `on*` 内联事件属性。剥进入缓存之前，内存缓存存的是剥离后字节。TXT 章节内容在 `TxtContentService.buildChapterHtml` 已整体转义，无脚本面，不再重复剥离。

实现选型是标签级扫描而非解析往返：注释、CDATA、DOCTYPE、处理指令原样保留；属性解析引号感知；无引号属性值在紧邻 `>` 的 `/` 前停止以保住自闭合斜杠（XHTML 按 XML 解析，丢斜杠即 malformed）；`style` 按 raw text 元素处理，CSS 文本里的 `<script>` 字样不误伤。脚本闭合匹配使用开标签的限定名（含命名空间前缀），避免找不到 `</svg:script>` 而丢弃后续正文。无脚本内容时输出与输入逐字节一致。

分页 CSS 保留原生表格布局，使长表格参与跨栏分页。`math` 元素超宽横向滚动、禁止跨栏断裂。

## Alternatives considered

**方案 (b)：ContentBlocker / shouldInterceptRequest 拦截脚本执行** —— 放弃。flutter_inappwebview 的 `ContentBlocker` 只在 iOS（WKWebView Content Rule List）生效，Android 无对应能力，两端行为会分裂；`shouldInterceptRequest` 已经是供给通道本身，在同一处直接改内容比再加一层"请求过滤"更简单，且剥离逻辑可纯函数单测。

**用 `package:xml` 或 `package:html` 完整解析后剔除节点再序列化** —— 放弃。EPUB 的 XHTML 常含 HTML 具名实体（`&nbsp;` 等），严格 XML 解析直接失败；即使解析成功，重序列化会改动与脚本无关的内容（实体形式、自闭合形态、属性顺序），供给层字节保真比结构优雅更重要。

**只靠 iframe sandbox，不做供给层剥离** —— 放弃。sandbox 强制力是 WebView 实现细节而非我们能验证的契约；供给层剥离是纵深防御，且让"书内脚本不可执行"成为供给通道的显式不变量。

**`javascript:` href 一并剥离** —— 放弃。链接点击经 `shouldOverrideUrlLoading` 已只放行 `book://` 与 `data:`，其余一律 CANCEL，已有等价防线。

**表格块级化并设 `overflow: auto`** —— 放弃。Chromium 将滚动容器视为不可跨栏拆分的整体，100 行表格只报告 1 页，其余行在视口下方；阅读器禁止原生触摸滚动，表内滚动无法让用户访问这些行。原生表格布局同时保留跨页能力与书籍的 `border-collapse` 样式。

## Consequences

- 已知取舍：依赖书内脚本的交互内容（内嵌小部件、脚本驱动的 quiz 等）从此静默失效，不给用户提示；有声书/脚本增强型 EPUB 属于主动放弃的能力。
- 剥离按 UTF-8 有损解码再编码：本就非法的字节序列会变成 U+FFFD（此前是 WebView 端容错，差异极小）；合法 UTF-8 且无脚本的内容逐字节不变。
- 不引入表内横向滚动；超宽表格仍依赖书籍排版和单元格换行适应页宽。
- MathML 依赖 WebView 原生 MathML Core，低端旧 WebView 可能不渲染公式；这是记录在 [reader 子系统文档](../../../../docs/subsystems/reader.md#已知限制与待办) 的已知限制，不引入 MathJax。

## Testing

- `test/features/reader/domain/xhtml_sanitizer_test.dart` 覆盖脚本剥离、内联事件属性剥离与保留区，包括带前缀脚本之后的 SVG 元素和正文完整保留。
- `web_assets/controller.js/tests/reader_lifecycle.spec.cjs` 在 Chromium 与 WebKit 的真实三 iframe 中验证 100 行长表格可翻到末页，并断言末行文字全部位于可视区域。
- 浏览器回归不替代 Android / iOS 真机对旧 WebView 的脚本拦截与分页体验验收。
