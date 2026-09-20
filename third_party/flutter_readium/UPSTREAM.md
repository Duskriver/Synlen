# flutter_readium 本地分支

本目录基于 [flutter_readium 0.5.0](https://pub.dev/packages/flutter_readium/versions/0.5.0)，上游为 [notalib/flutter_readium 的 v0.5.0 标签](https://github.com/notalib/flutter_readium/tree/v0.5.0/flutter_readium)。原始 [BSD 3-Clause 许可证](LICENSE)、README 和变更记录随源码保留。

上游归档地址为 `https://pub.dev/api/archives/flutter_readium-0.5.0.tar.gz`，SHA-256 为 `d795e392823ea236f8fbc9bc75e0ae1efc5d94f3646fb15ef626d081761134a1`。本目录保留 `lib/`、`android/`、`ios/`、`assets/`、`test/` 和包配置，省略示例、发布脚本及 macOS 占位插件。平台接口固定为 0.5.0；Android toolkit 固定为 3.3.0，iOS toolkit 固定为 3.11.0。

## 本地接口

`ReadiumReaderWidget` 增加 `sessionId`、`onTextInteraction`、`onLocatorChanged`、`onReaderReady`、`onReaderError`、`onReaderDisposed`、`handlePointerControls` 和 `handleInternalLinks`。应用为每次创建提供新的 `sessionId`。文字回执是最多 65536 个 UTF-16 单元的 JSON 字符串，原生层覆盖 `sessionId` 和 `resourceHref`；宿主仍负责校验版本、事件类型、正文长度和当前章节。学习提取逻辑属于应用资源。

单词消息携带可见 CSS 词包围矩形 `wordRect`、逐片段矩形 `wordRects` 与 CSS 视口尺寸 `viewport`。原生层丢弃消息自带的 `anchorRect`，从实际发送消息的 WebView 转换到 Flutter 平台视口内的逻辑坐标，再写入 `anchorRect: {x, y, width, height}` 并替换 `wordRects`。包围矩形用于定位卡片，逐片段矩形用于着色；未携带片段的旧消息退回包围矩形。Android 包含祖先滚动、原生页面偏移和视图变换，只在输出时换算一次屏幕密度；iOS 经 WebView 到容器的 UIKit 坐标转换。无效、不可见或不属于该视口的词矩形不转发；句子与空白点击不要求矩形。

`onReaderReady` 报告原生页面就绪；Android 的此回执可能早于可见位置查询，宿主须同时等待有效 Locator 才结束加载。位置查询通过应用脚本的 `window.synlenReadiumBridge.getVisibleLocator()` 取得 `locations.cssSelector` 与当前页短文本 `text`；无可唯一定位的文字时可返回 `null`，保留原生 Locator。资源身份或导航版本不符的异步结果丢弃，查询异常及超时通过 `LocatorUnavailable` 报告。字号、字体、行距等布局变化通过保存完整 Locator、移除视口、等待 `onReaderDisposed`、关闭出版物，再用新偏好和旧 Locator 创建视口来恢复位置。

拆除异常在内部重试一次；持续失败通过 `ReaderDisposalFailed` 报告，不能据此继续复用旧资源。销毁会等待在途平台视图创建，再等待所属阅读通道和平台视图拆除；只有从未开始创建的视口可以直接发出销毁回执。

旋转后的延迟落页校正属于当前视口：连续旋转替换待执行任务，销毁时取消定时器，执行前复核阅读通道身份。视口关闭或后续旋转使旧请求的错误回执失效；仍活动的校正失败通过 `LocatorUnavailable` 报告。

`handlePointerControls: false` 关闭 Flutter 的正文点击控制栏逻辑，保留语义操作；应用注入脚本负责词、句与正文空白手势。`handleInternalLinks: false` 禁止正文普通书内跳转，保留脚注；显式目录导航不受此开关影响。导航方法的 `animated` 参数传到原生视口，位置以回执为准。目录与恢复导航传递完整 Locator，保留锚点、CFI、扩展位置和媒体类型。

本地字体沿用 `ReaderFontFace(asset: Uri.file(path).toString())`，字体文件须在视口存活期间可读。iOS 交给 Readium 的文件字体资源服务；Android 将最多 32 MiB 的本地字体转为 CSS data URL，避免书籍 HTTPS 页面直接访问 file URL。普通 Flutter asset 字体仍按上游方式加载。

## 本地修补

[上游差异补丁](SYNlen.patch) 记录本地源码差异。重建时先校验上游归档摘要，解压后保留上述 5 个目录及 `LICENSE`、`README.md`、`CHANGELOG.md`、`analysis_options.yaml`、`pubspec.yaml`，在该目录执行 `patch -p1 < SYNlen.patch`。本说明与补丁是维护资料，不参与源码重放。嵌套的 `android/readium-navigator/` 不包含在此补丁内，须另按其 [来源与重建说明](android/readium-navigator/UPSTREAM.md) 还原。更新依赖时先重放补丁，再验证两端真实触摸、书内跳转、文字身份、字体加载、字号重建及快速关闭重开。

- Android 文字与图片桥绑定所属 fragment、navigator 和 widget；重复销毁不关闭新视口，EPUB 视口在关闭回包前同步拆除。
- iOS 注入列表、脚本和目录信息属于各自视口；文字身份由 WebKit 实际 frame URL 与出版物 reading order 匹配，关闭后丢弃异步回执。
- 两端补齐应用 JS/CSS 注入、本地字体、普通内部链接开关及视口回执；Dart 补齐外链回调、偏好更新等待和动画参数。
- Android 补充 Locator 目录标题时，当前资源没有目录项或只有一个目录项便直接返回；只有多个目录锚点需要扫描正文选择器。

本分支只支持应用串行打开单个活动出版物，不支持同一插件同时展示多本书。Readium 的页面 JavaScript 处于启用状态；书内脚本过滤由词镜准备出版物的流程承担，桥接身份字段不构成对书内脚本的隔离。

Android Navigator 使用固定 3.3.0 的本地源码模块，补充分页拖动的落页判定，以及绑定实际 WebView 的 JavaScript 桥工厂；其余 Readium 组件保留官方 Maven 依赖。Flutter 优先收集根 [NOTICES](NOTICES)，其中保留原插件、Readium、PhotoView 与随包字体的许可；原始许可证文件也随源码保留。

在仓库根目录执行 `bash tool/test_readium_android.sh`，同时验证插件 `flutter_readium` 与本地 Navigator `synlen_readium_navigator` 的单元测试。词锚点测试覆盖原生页偏移、缩放、祖先滚动、屏幕密度及无效来源；两端还须在设备验证分页、重排和词卡位置。

Android 构建使用 JDK 21、compile SDK 36、min SDK 24，并开启 core library desugaring；profile 变体对本地 Navigator 使用 release 回退。iOS 最低版本为 15。JDK 路径由构建环境配置，不写入仓库。

## Dev Note

None.
