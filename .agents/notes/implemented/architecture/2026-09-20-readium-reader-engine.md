# Agent Note: Readium 拥有阅读排版，词镜保留内容与学习会话

Status: implemented

## Problem

自研阅读器同时承担 EPUB 资源兼容、三 iframe 分页、位置恢复、平台翻页和学习触摸。排版缺陷与视口生命周期互相影响，单次修复需要理解从 Dart 到 DOM 的完成回执。产品需要稳定的 EPUB/TXT 阅读与学习能力，维护通用排版引擎的成本超过了这部分差异化价值。

## Decision

按 [issue 46](https://github.com/Duskriver/Synlen/issues/46) 将 Android / iOS 统一接到 Readium。本地 `third_party/flutter_readium` 固定上游 0.5.0，保留来源与许可证，只维护学习消息、可见文本定位、事件归属、资源和原生生命周期所需的补丁，不提供双引擎产品入口。

`ReadiumPublicationSource` 拥有出版物准备。TXT 按现有虚拟章节生成可重建的 EPUB，正文与清单是唯一真源。`ReadiumEpubPublicationCache` 校验包内条目并移除活动内容；无活动内容时沿用原包，需要修改时生成缓存副本，保持资源路径与字体字节。不能假定 Readium 禁用 JavaScript，自有学习 asset 仍需要执行。

`ReadiumSession` 拥有打开、就绪、重排、进度和关闭次序，原生能力经 `ReadiumGateway` 注入。分页、章内链接与脚注由 Readium 处理，Flutter 保留控制栏、图片、外链确认与学习入口。排版变化保存完整 Locator 后卸载视口并重开，不在旧物理页上直接修改字号；重排期间冻结进度，待有效资源定位后再采集。

进度直接采用 `BookProgress` 的完整 Locator JSON，保留文本上下文与 SDK 扩展字段，百分比只供书架展示。当前没有旧用户，不从章节序号／章内比例推算 Locator，不提供旧进度兼容路径；旧开发数据库要求明确重置，备份使用同一份完整定位数据。

Web 脚本负责词句提取、触摸判定和只读的可见短文本采样，不运行分页或滚动算法。原生将短文本、上下文与所属元素选择器写入标准 Locator，交给 Readium 的 TextQuoteAnchor 恢复跨页段落中的实际文字。JavaScript 发出词、句或控制栏消息，原生补入会话及资源身份，Dart 与当前 Locator 再核对。学习文字命中与原生翻页、链接、图片分别消费自己的手势；移动、多指和取消事件不得变成迟到点词。

## Alternatives considered

**继续修补自研分页**：仍需维护 EPUB 布局、字体、跨栏表格及两端 WebView 差异，无法缩小长期维护面。

**保留双引擎入口**：每项主题、进度与学习功能都需要两套验收，持久化模型也被旧分页坐标牵制。产品没有存量用户，保留旧入口缺少实际调用需求。

**只保存 href 与 progression**：比例不能描述字体变化后的同一段落，舍弃 Locator 的 DOM／文本定位信息后难以恢复精确位置。

**为旧章内比例实现迁移**：桌面旧 Renderer 与 Android Readium 样例只能证明可定位到相近段落，不能证明原段落不丢；没有需要迁移的用户数据，增加兼容代码没有收益。

**改字号时只调用偏好 setter**：原型中两端等待数秒后仍跳到靠前段落，Android 还会保留旧 Locator；因此采用保存定位、卸载并重开视口的路径，并以原段落可见作为验收依据。

**复用原生文本选择菜单做学习**：产品需要点词附带整句和长按直接学句，选择手柄、菜单与翻页竞争触摸；独立的小型学习脚本能复用严格词句提取并明确消费规则。

## Consequences

TXT 缓存按现有清单连续覆盖全部 UTF-8 正文，元数据与源内容摘要共同决定缓存键；写入先落临时文件再原子改名。源改变或清单过期时必须重新准备，不能生成只含部分章节的书。EPUB 准备先验证真实解压长度与 CRC，再以 XML 解析活动内容；标准 XHTML 命名实体可读，自定义 DTD 或畸形内容明确失败。净化副本保留原条目路径、OPF 标识符、混淆声明和字体字节。

完整 Locator 原样落库，阅读百分比按章节等权估算，不能用于恢复。数据库 schema 3 与开发阶段的旧坐标不兼容；当前没有旧用户，开发数据库按[开发说明](../../../../docs/development.md)明确重置，不加入旧进度转换链。备份使用同一份完整定位数据。

只保存段落选择器会把跨页段落恢复到段首，同字号重开也可能退一页。可见短文字及所属元素选择器交给 SDK 的标准 TextQuoteAnchor，使恢复目标落在原来可见的文字上；没有唯一文本锚点的页面保留 SDK 的其他定位字段。原生查询同时验证文档身份与位置版本，迟到结果不能覆盖新页面。

Readium 插件的全局出版物状态要求前后会话串行交接。创建尚未完成的视口也必须等待创建结果、移除自身通道并释放平台资源后确认关闭。iOS 的可见 Locator 查询等待实际排版回执，期限为 15 秒；长表首次排版超过 5 秒是正常可读内容，不能提前当作打开失败。

## Testing

2026-09-20 的最终验证包括 Flutter 单测 471 项通过、2 项既有跳过；Chromium / WebKit 的 114 项脚本回归通过；插件 Dart 通道、创建／销毁与完整 Locator 的 14 项回归通过。内容准备测试覆盖全量 TXT、缓存失效、XML 实体与命名空间、脚本和事件移除、CRC 损坏拒绝及字体字节保留；实际 TXT 派生 EPUB 通过 EPUBCheck，零错误与警告。

[设备测试](../../../../integration_test/reader_smoke_test.dart)在 Android 模拟器与 iOS 27 的 iPhone 18 Pro 模拟器通过真实导入、翻页、跨章、字号 1 → 1.5、完整 Locator 入库、退出重开与连续三次快速退出。截图确认 Android 的目标段落 C2-P26 与 iOS 的 C2-P31 在重排后仍可见；同字号重开分别保持第 5／23 页与第 7／21 页，Locator 与可见正文一致。两端均可到达长表后的 TABLE_AFTER_100_END、普通 SVG 与 AFTER_INLINE_SVG_VISIBLE。

原生触摸分别经 adb 与 XCTest 输入，点词携带完整句子；900 毫秒长按仅发送同一句子，不重复点词或切换控制栏。设备测试用记录入口替代学习请求，不调用 AI 服务。该证据与浏览器手势回归分别覆盖原生分发与 DOM 判定。

Android 普通应用入口的调试 APK 已安装并正常打开空书架，通过 16 KiB ZIP 对齐检查，8 个 arm64 ELF 的加载段均满足 16 KiB 对齐；交付产物 SHA-256 为 `bbf79e63926809a980f68d5e7d7c30684b6d6f431ba24fe3c955258eb56e9b0c`。这些模拟器与产物检查不提供真机性能、低内存或全部 EPUB 藏书的兼容性基线。

## Supersedes

完整替代并归档：旧[导航状态机](../../archived/architecture/2026-09-09-reader-navigation-state-machine.md)、[流程回执](../../archived/architecture/2026-09-19-reader-workflow-render-contract.md)、[渲染器拆分](../../archived/architecture/2026-09-09-reader-renderer-split.md)、[回调聚合](../../archived/architecture/2026-09-09-renderer-callbacks-bundle.md)、[WebView 封装](../../archived/architecture/2026-09-09-reader-webview-part-files.md)、[舞台](../../archived/architecture/2026-09-09-reader-stage.md)、[目录和图片层](../../archived/architecture/2026-09-09-reader-toc-state-and-image-overlay.md)、[导航提示](../../archived/architecture/2026-09-09-reader-nav-feedback.md)、[加载遮罩](../../archived/bug-fix/2026-09-10-reader-loading-overlay-stale.md)、[虚拟域](../../archived/architecture/2026-09-09-book-scheme-rename.md)、[虚拟域处理器](../../archived/architecture/2026-09-09-book-webview-handler-rename.md)、[EPUB 后端 seam](../../archived/architecture/2026-09-09-epub-backend-seam.md)、[空预热清理](../../archived/simplification/2026-09-09-remove-epub-stream-warmup.md)及[双资源管线](../../archived/simplification/2026-09-12-webview-resource-pipeline-dedup.md)。

部分取代：[BookQueries 窄视图](../../implemented/architecture/2026-09-09-book-queries-reader-view.md)继续约束跨 feature 接口，[控制栏拆分](../../implemented/architecture/2026-09-09-reader-control-bar-split.md)继续约束按钮与计时器归属，[脚本剥离](../../implemented/bug-fix/2026-09-09-book-script-stripping.md)的安全承诺继续生效，具体供给路径由出版物准备替代虚拟域。

手势归属与 Android 原生落页判定由[阅读手势修复决策](../bug-fix/2026-09-20-readium-reader-gestures.md)部分补充；出版物供给、排版所有权与完整 Locator 的决策继续有效。

重复打开的文件校验复用和 Android 目录标题的按需解析由[重开成本修复](../bug-fix/2026-09-20-readium-reopen-cost.md)部分补充，首次净化和完整 Locator 的约束继续有效。
