# reader

reader 模块负责阅读：把 `BookManifest` 变成可翻页的 WebView 内容，并记录阅读进度。本页 owns 这些类型、语义与边界；阅读数据流见 [architecture.md](../architecture.md#数据流)。

## 职责

- 内容供给：`book://` 虚拟域拦截 + 内存缓存；TXT 按字节范围切片包装为 XHTML。
- 会话：加载书目与清单、过滤 spine、建 TOC 查找表、生成章节 URL。
- 导航：章节预载窗口、章内翻页与跨章边界判定、平台翻页动画。
- 进度：防抖落库，失败保留最新位置。
- 交互：脚注、图片、外链、阅读主题四类 mixin，以及三 iframe 渲染骨架。
- reader Web 资源：`web_assets/` 源经构建脚本生成 `lib/src/web/web_assets.dart`。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `ReaderWorkflow` | 阅读会话：导航、主题队列、进度采集与关闭；错误转成状态，关闭后忽略迟到结果 | `lib/src/features/reader/application/reader_workflow.dart` |
| `ReaderSessionFactory` | 装配入口：`createWorkflow` 组合导航与进度，`createSession` 建 `BookSession`，`createWebViewHandler` 建内容供给处理器；屏幕不读 data provider | `lib/src/features/reader/application/reader_session_factory.dart` |
| `ReaderNavigator` / `ReaderNavState` / `ReaderNavOutcome` | 导航状态机：章节与页面位置、忙态守卫、预载与跳转编排；状态经 `ValueNotifier` 暴露，结果枚举由展示层映射文案 | `lib/src/features/reader/application/reader_navigator.dart` |
| `ReaderViewport` | 导航编排需要的渲染引擎能力（准备章节窗口、跳转、排版、恢复滚动位置；Future 完成即操作完成）；`ReaderRendererController` 是生产实现，测试用 fake | `lib/src/features/reader/application/reader_viewport.dart` |
| `BookSession` | 一次阅读会话：加载 `ReaderBookView` 与 `ReaderManifestView`、过滤 spine、建 TOC 查找表、算进度比例、生成 URL | `lib/src/features/reader/application/book_session.dart` |
| `BookWebViewHandler` | `book://` 虚拟域请求处理：内存 LRU 缓存、字体请求、按格式分发到 EPUB 或 TXT | `lib/src/features/reader/application/book_webview_handler.dart` |
| `EpubStreamService` / `EpubBackend` | EPUB 内容读取：切书关闭旧缓存、取条目、扩展名到 MIME；Rust 调用经 `EpubBackend` 接口，测试用 fake | `lib/src/features/reader/data/services/epub_stream_service.dart` |
| `TxtContentService` | TXT 章节供给：按 `SpineItem.sourceRange` 随机读取字节并包装为 XHTML | `lib/src/features/reader/data/services/txt_content_service.dart` |
| `sanitizeBookXhtml` / `needsScriptStripping` | 书内脚本剥离：标签级扫描剥掉 `<script>` 元素与 `on*` 内联事件属性，及哪些 MIME 的书内容需要剥离 | `lib/src/features/reader/domain/xhtml_sanitizer.dart` |
| `ReadingProgressController` | 进度防抖（默认 1 秒）与串行落库；关闭时 flush，失败保留最新位置 | `lib/src/features/reader/application/reading_progress_controller.dart` |
| `ChapterPreloadRequest` / `ChapterSlot` / `planChapterPreload` / `planNeighbourPreload` / `shouldIgnoreChapterNavigation` | 章节预载窗口与翻章忙态守卫 | `lib/src/features/reader/application/chapter_navigation.dart` |
| `PageTurnBoundary` / `resolvePageTurnBoundary` / `pageTurnTargetIndex` | 翻页边界与章内目标页判定 | `lib/src/features/reader/application/page_navigation.dart` |
| `generateSkeletonHtml` | 三 iframe 骨架页 HTML，注入初始配置与分页 CSS | `lib/src/features/reader/application/reader_scripts.dart` |
| `ReaderSettings` / `ReaderLinkHandling` / `ReaderPageAnimation` | 阅读器可配置项：字号、边距、主题、外链策略、翻页动画、自定义字体、音量键翻页 | `lib/src/features/reader/domain/reader_settings.dart` |
| `ReaderSettingsNotifier` | 阅读设置持久化与修改（`SharedPreferences`） | `lib/src/features/reader/application/reader_settings_notifier.dart` |
| `EpubTheme` / `colorToHex` | 阅读器配色，与全局 `AppThemeSettings` 解耦 | `lib/src/features/reader/domain/epub_theme.dart` |
| `ReadingProgress` | 完成分页后的位置：章节序号、章内页码、章内总页数 | `lib/src/features/reader/domain/reading_progress.dart` |
| `VolumeControlService` / `VolumeKeyPageTurnController` | 音量键翻页：前者封装平台拦截与事件流，后者按启用条件订阅并把事件映射为翻页动作 | `lib/src/features/reader/application/volume_control_service.dart` |
| `ReaderScreen` / `ReaderRenderer` / `ReaderWebView` / `ControlPanel` / `ReaderBottomBar` / `TocDrawer` | 屏幕、三 iframe 渲染器、InAppWebView 封装、控制面板与底部控制条、目录抽屉 | `lib/src/features/reader/presentation/` |
| `AndroidPageTurnSession` / `IOSPageTurnSession` | 平台翻页动画 | `lib/src/features/reader/presentation/page_turn/` |
| 展示层 part mixin | `theme` / `link_handling` / `image_viewer` / `footnote`；主题解析、外链确认、图片与脚注展示 | `lib/src/features/reader/presentation/mixins/` |

## 流程

1. 打开：`ReaderSessionFactory.createWorkflow(fileHash, viewport)` → `ReaderWorkflow.open()` → `BookSession.loadBook()` → 过滤 `linear: false` 的 spine → 建 TOC 查找表。
2. 供给：WebView 请求 `book://localhost/book/{fileHash}/{path}` → `BookWebViewHandler` 命中内存缓存或按书格式分发；TXT 由 `TxtContentService` 切片包装 XHTML。
3. 导航：`ReaderWorkflow` 统一调用 `ReaderNavigator`；后者 按 `planChapterPreload` 的窗口经 `ReaderViewport.prepareChapters` 准备当前 / 上一章 / 下一章 → `ReaderRenderer` 装载三 iframe；翻页边界由 `resolvePageTurnBoundary` 判定，章内目标页由 `pageTurnTargetIndex` 给出，越界则跨章。
4. 进度：会话监听导航状态 → `ReadingProgressController.record` 校验位置 → 防抖 1 秒 → `BookSession.saveProgress` → `BookQueries.saveProgress`；离开阅读器时 `close()` 提交在途进度。
5. Web 资源：改 `web_assets/` 的 TypeScript / CSS 后跑 `dart run tool/build_web_assets.dart` 重新生成 `lib/src/web/web_assets.dart`，验证步骤见 [修改阅读器 Web 资源](../cookbook/changing-reader-web-assets.md)。

## 边界与不变量

- `ReaderSettings.themeIndex` 直接索引 `SynlenThemePreset`，索引含义由 core 的主题枚举顺序决定。
- 分页引擎未就绪（`isReady` 为 false）或位置非法时不采集进度。
- `BookWebViewHandler` 的缓存上限为 256 项、24 MiB，单条资源超过 2 MiB 不入缓存。
- `TxtContentService` 按 UTF-8 字节范围读取；章节切分不得拆开 UTF-16 代理对。
- `BookSession.saveProgress` 在书籍未加载或位置非法时抛错，由调用方处理。
- `EpubStreamService` 记录当前书籍路径：切换书籍时先关闭上一本，`dispose` 关闭当前书；Rust 侧缓存不随阅读累积。
- EPUB 的 XHTML/HTML/XML/SVG 供给前经 `sanitizeBookXhtml` 剥离 `<script>` 与 `on*` 属性（在 `BookWebViewHandler` 入缓存前执行，缓存里存的是剥离后字节）；骨架 iframe 的 `sandbox="allow-same-origin"` 是第一道防线，供给层剥离不依赖 WebView 对 sandbox 的强制力。TXT 章节内容整体转义，无脚本面。
- 导航或主题刷新在途时忽略新导航；主题请求串行且合并为最新参数，排版完成前不采集位置。WebView 回执超时、执行失败或卸载均转为阅读错误状态；同一原生视口由预加载转为可见只更新执行器，保留在途回执。

## 已知限制与待办

- 图片、脚注、外链确认和系统主题解析留在展示层；它们依赖 Flutter 上下文，验证需 widget 或设备测试。
- 阅读会话与桥接协议可独立单测；真实 WebView 的验证入口见[测试现状](../testing.md#现状)。
- `BookWebViewHandler` 同时服务 EPUB 与 TXT，虚拟域格式中立（`book://`）。
- 表格保留原生布局并跨栏分页，不提供表内横向滚动；超宽表格依赖书籍排版和单元格换行适应页宽。
- MathML 不做重型引入（不引入 MathJax）：分页 CSS 只保证 `math` 不被列宽规则压坏（超宽公式横向滚动、禁止跨栏断裂），渲染依赖 WebView 原生 MathML Core（Android System WebView Chromium 109+ / 现代 WKWebView），低端旧 WebView 可能不渲染公式。
- 超 400 行文件：`reader_screen.dart`。复现：

```sh
find lib/src/features/reader -name '*.dart' ! -name '*.g.dart' -exec wc -l {} + | sort -rn | head
```

## Dev Note

None.
