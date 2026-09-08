# reader

reader 模块负责阅读：把 `BookManifest` 变成可翻页的 WebView 内容，并记录阅读进度。本页 owns 这些类型、语义与边界；阅读数据流见 [architecture.md](../architecture.md#数据流)。

## 职责

- 内容供给：`epub://` 虚拟域拦截 + 内存缓存；TXT 按字节范围切片包装为 XHTML。
- 会话：加载书目与清单、过滤 spine、建 TOC 查找表、生成章节 URL。
- 导航：章节预载窗口、章内翻页与跨章边界判定、平台翻页动画。
- 进度：防抖落库，失败保留最新位置。
- 交互：脚注、图片、外链、阅读主题四类 mixin，以及三 iframe 渲染骨架。
- reader Web 资源：`web_assets/` 源经构建脚本生成 `lib/src/web/web_assets.dart`。

## 关键类型

| 类型 | 语义 | 位置 |
|---|---|---|
| `ReaderSessionFactory` | 装配入口：`createSession` 建 `BookSession`，`createWebViewHandler` 建内容供给处理器；屏幕不读 data provider | `lib/src/features/reader/application/reader_session_factory.dart` |
| `ReaderNavigator` / `ReaderNavState` / `ReaderNavOutcome` | 导航状态机：章节与页面位置、忙态守卫、预载与跳转编排；状态经 `ValueNotifier` 暴露，结果枚举由展示层映射文案 | `lib/src/features/reader/application/reader_navigator.dart` |
| `ReaderViewport` | 导航编排需要的渲染引擎能力（预载、跳转、恢复滚动位置）；`ReaderRendererController` 是生产实现，测试用 fake | `lib/src/features/reader/application/reader_viewport.dart` |
| `BookSession` | 一次阅读会话：加载 `ShelfBook` 与 `BookManifest`、过滤 spine、建 TOC 查找表、算进度比例、生成 URL | `lib/src/features/reader/application/book_session.dart` |
| `EpubWebViewHandler` | `epub://` 虚拟域请求处理：内存 LRU 缓存、字体请求、按格式分发到 EPUB 或 TXT | `lib/src/features/reader/application/epub_webview_handler.dart` |
| `EpubStreamService` | EPUB 内容读取：打开 / 关闭 Rust 侧缓存、取条目、扩展名到 MIME | `lib/src/features/reader/data/services/epub_stream_service.dart` |
| `TxtContentService` | TXT 章节供给：按 `SpineItem.sourceRange` 随机读取字节并包装为 XHTML | `lib/src/features/reader/data/services/txt_content_service.dart` |
| `ReadingProgressController` | 进度防抖（默认 1 秒）与串行落库；关闭时 flush，失败保留最新位置 | `lib/src/features/reader/application/reading_progress_controller.dart` |
| `ChapterPreloadRequest` / `ChapterSlot` / `planChapterPreload` / `planNeighbourPreload` / `shouldIgnoreChapterNavigation` | 章节预载窗口与翻章忙态守卫 | `lib/src/features/reader/application/chapter_navigation.dart` |
| `PageTurnBoundary` / `resolvePageTurnBoundary` / `pageTurnTargetIndex` | 翻页边界与章内目标页判定 | `lib/src/features/reader/application/page_navigation.dart` |
| `generateSkeletonHtml` | 三 iframe 骨架页 HTML，注入初始配置与分页 CSS | `lib/src/features/reader/application/reader_scripts.dart` |
| `ReaderSettings` / `ReaderLinkHandling` / `ReaderPageAnimation` | 阅读器可配置项：字号、边距、主题、外链策略、翻页动画、自定义字体、音量键翻页 | `lib/src/features/reader/domain/reader_settings.dart` |
| `ReaderSettingsNotifier` | 阅读设置持久化与修改（`SharedPreferences`） | `lib/src/features/reader/application/reader_settings_notifier.dart` |
| `EpubTheme` / `colorToHex` | 阅读器配色，与全局 `AppThemeSettings` 解耦 | `lib/src/features/reader/domain/epub_theme.dart` |
| `ReadingProgress` | 完成分页后的位置：章节序号、章内页码、章内总页数 | `lib/src/features/reader/domain/reading_progress.dart` |
| `VolumeControlService` | 音量键翻页 | `lib/src/features/reader/application/volume_control_service.dart` |
| `ReaderScreen` / `ReaderRenderer` / `ReaderWebView` / `ControlPanel` / `ReaderBottomBar` / `TocDrawer` | 屏幕、三 iframe 渲染器、InAppWebView 封装、控制面板与底部控制条、目录抽屉 | `lib/src/features/reader/presentation/` |
| `AndroidPageTurnSession` / `IOSPageTurnSession` | 平台翻页动画 | `lib/src/features/reader/presentation/page_turn/` |
| 5 个 part mixin | `progress` / `theme` / `link_handling` / `image_viewer` / `footnote` | `lib/src/features/reader/presentation/mixins/` |

## 流程

1. 打开：`ReaderSessionFactory.createSession(fileHash)` → `BookSession.loadBook()` → 过滤 `linear: false` 的 spine → 建 TOC 查找表。
2. 供给：WebView 请求 `epub://localhost/book/{fileHash}/{path}` → `EpubWebViewHandler` 命中内存缓存或按书格式分发；TXT 由 `TxtContentService` 切片包装 XHTML。
3. 导航：`ReaderNavigator` 按 `planChapterPreload` 的窗口经 `ReaderViewport` 预载当前 / 上一章 / 下一章 → `ReaderRenderer` 装载三 iframe；翻页边界由 `resolvePageTurnBoundary` 判定，章内目标页由 `pageTurnTargetIndex` 给出，越界则跨章。
4. 进度：`ReadingProgressController.record` 校验位置 → 防抖 1 秒 → `BookSession.saveProgress` → `BookQueries.saveProgress`；离开阅读器时 `close()` 提交在途进度。
5. Web 资源：改 `web_assets/` 的 TypeScript / CSS 后跑 `dart run tool/build_web_assets.dart` 重新生成 `lib/src/web/web_assets.dart`，验证步骤见 [修改阅读器 Web 资源](../cookbook/changing-reader-web-assets.md)。

## 边界与不变量

- `ReaderSettings.themeIndex` 直接索引 `SynlenThemePreset`，索引含义由 core 的主题枚举顺序决定。
- 分页引擎未就绪（`isReady` 为 false）或位置非法时不采集进度。
- `EpubWebViewHandler` 的缓存上限为 256 项、24 MiB，单条资源超过 2 MiB 不入缓存。
- `TxtContentService` 按 UTF-8 字节范围读取；章节切分不得拆开 UTF-16 代理对。
- `BookSession.saveProgress` 在书籍未加载或位置非法时抛错，由调用方处理。
- `EpubStreamService` 记录当前书籍路径，`dispose` 关闭该书在 Rust 侧的缓存条目。
- 翻章期间（加载中、主题刷新中、正在翻章）忽略新的章节导航请求。

## 已知限制与待办

- `reader/presentation` 仍是最大的 UI 层，剩余 5 个 part mixin（进度显示、主题刷新、外链、图片、脚注）的逻辑继续下沉 `reader/application`。
- 这 5 个 mixin 是 part 文件（依赖 `reader_screen.dart`），单测需先拆分或改 widget test（[测试现状](../testing.md#现状)）。
- `EpubWebViewHandler` 与 `epub://` 虚拟域同时服务 EPUB 与 TXT；修复方向是格式中立命名（如 `BookWebViewHandler`、`book://`），改名牵连 URL 拦截与 JS 侧资源引用，需独立评估。
- 切换书籍不关闭上一本的 Rust 缓存条目：`EpubStreamService` 为 keepAlive，`closeEpub` 只在它被销毁时调用，同一会话内连续打开多本书会累积缓存条目（见 [rust.md](rust.md)）。
- 超 400 行文件：`reader_screen.dart`、`reader_renderer.dart`。复现：

```sh
find lib/src/features/reader -name '*.dart' ! -name '*.g.dart' -exec wc -l {} + | sort -rn | head
```

## Dev Note

None.
