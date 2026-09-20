# reader

阅读模块参考：Readium 出版物供给、会话、定位、学习手势与展示。模块边界见 [architecture.md](../architecture.md)，设计理由见 [Readium 引擎决策](../../.agents/notes/implemented/architecture/2026-09-20-readium-reader-engine.md)。

## 职责与入口

- `ReaderSessionFactory` 装配单个 `ReadiumSession`，并等待前一个会话完成保存和关闭。
- `ReadiumPublicationSource` 校验 EPUB 并缓存移除活动内容后的副本；TXT 按已有虚拟章节生成派生 EPUB 缓存，源 TXT 与藏书清单仍是真源。
- Readium 原生 Navigator 拥有分页、资源加载、书内导航与脚注；Flutter 展示阅读控件、图片和外链确认。
- Web 脚本命中文字时提取词句，并按原生请求只读采集当前可见短文本；Flutter 经 `LearningEntry` 调用学习能力，原生将短文本写入标准 Locator 交给 Readium 恢复位置。

## 类型与语义

| 类型 | 语义 | 定义 |
|---|---|---|
| `ReadiumSession` / `ReaderFailure` | 打开、重排、导航、事件校验与关闭；错误在 application 转为状态 | `lib/src/features/reader/application/readium_session.dart` |
| `ReaderSessionFactory` | 注入内容供给、书目接口和原生 gateway；串行交接全局出版物 | `lib/src/features/reader/application/reader_session_factory.dart` |
| `ReadiumGateway` / `NativeReadiumGateway` | 会话依赖的原生能力；测试以 fake 控制打开、导航与关闭时序 | `lib/src/features/reader/application/readium_gateway.dart` |
| `ReadiumPublicationSource` / `PreparedReadiumPublication` | 本地文件路径与窄书目视图；准备失败交由会话处理 | `lib/src/features/reader/application/readium_publication_source.dart` |
| `ReadiumEpubPublicationCache` | 校验 ZIP 与内容文档；无活动内容时沿用原包，否则生成净化副本 | `lib/src/features/reader/data/readium_epub_publication_cache.dart` |
| `ReadiumTxtPublicationCache` | 按正文与清单摘要生成 EPUB；同一请求合并，缓存可删除重建 | `lib/src/features/reader/data/readium_txt_publication_cache.dart` |
| `TxtContentService` / `TxtSpineSource` | 按 UTF-8 字节范围取得虚拟章节；TXT 正文整体转义为 XHTML | `lib/src/features/reader/data/services/txt_content_service.dart` |
| `ReadiumLayout` | 将字号、主题与导入字体转为原生参数；随视口重建应用 | `lib/src/features/reader/application/readium_layout.dart` |
| `BookProgress` | 原样保存完整 Locator JSON，另带书架百分比；文本上下文及扩展字段不丢弃 | `lib/src/features/library/domain/book_progress.dart` |
| `ReadingProgressController` | 进度防抖和串行落库；关闭时 flush，失败保留待保存位置 | `lib/src/features/reader/application/reading_progress_controller.dart` |
| `ReadiumInteraction` | 验证原生消息版本、会话与资源路径，再解析词、句或控制栏动作 | `lib/src/features/reader/domain/readium_interaction.dart` |
| `ReaderSettings` / `ReaderLinkHandling` / `ReaderPageAnimation` | 字号、边距、主题、链接策略、翻页动画、导入字体与音量键翻页 | `lib/src/features/reader/domain/reader_settings.dart` |
| `EpubTheme` | 阅读配色与边距，与全局主题配置解耦 | `lib/src/features/reader/domain/epub_theme.dart` |
| `VolumeControlService` / `VolumeKeyPageTurnController` | 平台按键事件与按启用条件订阅的翻页动作 | `lib/src/features/reader/application/volume_key_page_turn.dart` |
| `ReaderScreen` / `ReaderPageStage` / `ReadiumViewport` / `ControlPanel` / `TocDrawer` | 页面生命周期、留白命中、原生视口、控制面板与目录 | `lib/src/features/reader/presentation/` |

## 边界与不变量

- EPUB 准备层移除脚本、事件属性与可执行嵌入内容；原生 SDK 的 JavaScript 开关不承担此保证。无活动内容的原包不改写，副本保留资源路径、标识符与字体字节。
- EPUB 内容交由 Readium 解析；TXT 缓存必须完整覆盖清单中的连续 UTF-8 字节范围，清单过期或源文件变化时拒绝生成。
- 完整 Locator 是恢复位置的依据；页码和书架百分比只供展示，不反向合成精确定位。百分比按阅读顺序中的章节等权、结合章内比例估算，不表示全书字数比例。
- 可见短文本与所属元素选择器组成标准文本锚点，包含原始上下文；查询不滚动或修改 DOM，匹配与恢复由 Readium 负责。
- 排版变更先保存有效 Locator、停止采集、卸载视口，再串行关闭并重开出版物；ready 与匹配章节的位置同时到达后才恢复采集。
- 原生视口绑定 sessionId。过期视口事件、非当前资源的学习事件、未就绪位置均不得触发学习或覆盖进度。
- 学习脚本报告的 `href` 只用于诊断；可信 `sessionId` 与 `resourceHref` 由原生层补入，Dart 再与当前会话、Locator 核对。
- 点词携带完整句子；550ms 长按文字触发句子学习。位移超过 10 CSS px、多指、滚动与取消事件终止该手势，迟到 click 不补发学习或控制栏动作。
- 左右各 24 CSS px 留给原生翻页；链接、图片、表单与媒体透传给 Readium。中心空白短点只切控制栏，正文原生 selection 与上下文菜单禁用。
- `ReaderPageStage` 接收原生视口外的 Flutter 留白短点，包括底部进度区域；多指、长按、移动与取消不得打开菜单。控制栏切换要求会话就绪，且没有学习浮层或抽屉。
- 词句提取按语义块建立 DOM 偏移映射，保留内联连续性；隐藏内容、注音、脚本、SVG 和 MathML 不进入学习上下文。真实字符矩形命中后才取词，英文缩写歧义不保证全部消除。
- `ReaderSettings.themeIndex` 索引 core 的主题枚举；外链只允许受支持的协议并遵循阅读器外链策略。
- 关闭等待进度提交与原生资源释放；失败通过阅读错误状态与日志报告。

## 开发与验证

Web 脚本构建和 DOM 回归见 [修改阅读器 Web 资源](../cookbook/changing-reader-web-assets.md)。会话 fake 测试验证异步次序，设备测试验证真实 Readium 视口与学习流程，入口见 [测试](../testing.md)。本地插件 fork 的来源、修改范围与许可证随 `third_party/flutter_readium/` 保存。

Android Navigator 固定源码并补齐拖动停顿后的落页判定，来源、补丁与升级边界见[手势修复决策](../../.agents/notes/implemented/bug-fix/2026-09-20-readium-reader-gestures.md)。

## 已知限制与待办

- 页数随设备、字体与排版变化，不承诺不同平台页码相同；字体变化后的恢复按可见段落验收。
- 脚注、SVG、长表与字体需以规范有效的 EPUB 在两端实测；单本打开成功不能代表全部 EPUB 内容兼容。
- 桌面 Chromium / WebKit 的手势测试不覆盖原生 WebView 坐标、系统手势、后台恢复或低内存销毁。

## Dev Note

模拟器实测结果见引擎决策记录；这些结果不构成真机性能基线。
