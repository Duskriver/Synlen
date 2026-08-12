
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### 中文

#### 新功能

* **AI 服务 API Key 用户自配（BYOK）**：DeepSeek 与阿里云 TTS 的 API Key 改为在「设置 → AI 服务」中由用户自行填写，存于系统安全存储（Keychain/Keystore）。源码与构建产物不再包含任何密钥，为开源分发扫清障碍。
* **App 内更新（Android 直接安装 / iOS 跳 App Store）**：检查更新后 Android 可直接下载 APK 并安装（含下载进度与未知来源引导），iOS 跳转 App Store（上架后生效）；蓝奏云 / GitHub 保留为备选下载入口。
* **更新分发迁移到阿里云 OSS**：`version.json` 与 APK 托管在 OSS，国内网络可达；新增 `tool/upload_release.sh` 一键发布脚本（自动生成 version.json + 上传），CI 构建的 versionCode 从 tag 派生并递增（`v0.3.0` → `300` 规则），覆盖安装不再被拒。

#### 变更与优化

* 移除 CI 中的 API Key 注入与相关 GitHub Secrets 依赖（发布流水线不再涉及任何密钥）。
* 移除 `--dart-define` 传 Key 的运行方式，改为 App 内设置项。
* **日志统一迁移到 logger**：54 处 debugPrint 全部迁移到全局共享 logger（`core/services/app_logger.dart`），删除失效的 ignore 注释与注释掉的 print，并启用 `avoid_print` lint。

#### 工具链与依赖升级

* **Flutter 3.44.9 / Dart 3.12.2 / Rust 1.97.1**：工具链升级到最新稳定版，并新增 `rust-toolchain.toml` 固定 Rust 版本（可复现构建）。
* **数据库迁移 Isar → drift**（ADR-0002）：Isar 已停更 3 年且与新版 codegen 链不兼容，迁移到活跃维护的 drift（SQLite）。因项目从未对外发布、无存量 Isar 数据，无需数据迁移（见 ADR-0002 更新）。
* **Riverpod 3.x**：状态管理升级到 Riverpod 3（`flutter_riverpod 3.3.2` + `riverpod_annotation 4.0.3` + `riverpod_generator 4.0.4`）。`XxxRef` 参数统一为 `Ref`，Notifier provider 命名去掉 `Notifier` 后缀，`StateProvider` 改为 `Notifier` 实现。注：受 Flutter 3.44 生态锁限制（analyzer 12），riverpod 3.4.x / generator 4.0.6+ 待 Flutter 升级后解锁。
* **依赖全面升级**：`flutter_rust_bridge 2.12.0`（Dart+Rust 同步）、`xml 7`、`go_router 17.4`、`dio 5.11`、`flutter_secure_storage 11`、`share_plus 13`、`wakelock_plus 1.7`、`package_info_plus 10`、`saf_stream 4` 等全部升级到当前 Flutter stable 可支持的最新版本。
* **移除停更/无用依赖**：`isar`（→drift）、`isar_generator`、`flutter_speed_dial`（→ 自研 `ExpandableFab`，停更 3 年）、`saf_util`（无使用处）。
* **代码清理**：`analyze` 零告警、测试全绿；死代码（Rust `greet`、`EpubStreamService.warmUp`）留待后续专项重构（见架构审计报告）。
* **移除迁移代码**：按 ADR-0002 更新，删除旧 Isar 迁移代码与迁移测试（无存量数据，无需迁移）。

## [v0.2.3] - 2026-03-13

### English

#### Added

* **Volume Key Paging**: Added support for turning pages using volume keys on Android devices.
* **Keep Awake**: Added a feature to keep the screen awake while on the reading interface.
* **Check for Updates**: Added a built-in check for updates feature.
* **Footnote Images**: Added support for displaying images embedded within footnotes.
* **SVG Viewer**: Added SVG format support to the image viewer.
* **Duokan Support**: Added broader support for Duokan platform-specific formatting features.

#### Changed

* **AI Word Interpretation**: Enhanced AI prompts for word interpretation to include phonetic symbols, parts of speech, and contextual analysis.
* **AI Sentence Analysis**: Improved AI sentence analysis to prioritize natural Chinese translations and provide concise grammatical breakdowns.
* **Performance & UX**: Optimized overall rendering performance and reading user experience.
* **Title Truncation**: Long book titles on the home page now truncate in the middle for better visual balance.
* **Rendering Styles**: Polished and optimized internal book rendering styles.
* **Book Details**: Optimized the text display for the description section on the book details page.

#### Fixed

* **Settings State**: Fixed an issue where UI state was lost when items in the settings interface were scrolled off-screen.
* **Custom Fonts**: Fixed various bugs related to the application of custom fonts.

### Chinese

#### 新增

* **音量键翻页**：新增 Android 端的音量键翻页功能。
* **屏幕常亮**：阅读界面新增保持屏幕常亮特性。
* **检查更新**：应用内新增检查更新功能。
* **脚注图片**：新增对书籍脚注中内嵌图片的支持。
* **SVG 支持**：图片查看器新增对 SVG 格式图片的支持。
* **多看特性**：添加了更多对多看平台特有排版特性的兼容支持。

#### 变更与优化

* **AI 单词解释优化**：优化了 AI 单词解释的 Prompt，增加了音标、词性、变形及上下文作用分析。
* **AI 句子分析优化**：优化了 AI 句子分析的 Prompt，优先显示整句翻译并精简了语法分析内容。
* **性能与体验**：全面优化了底层渲染性能与整体用户体验。
* **标题省略**：主页的书籍标题过长时，现已改为在中间省略，提升视觉平衡。
* **渲染优化**：优化了书籍的排版与渲染样式。
* **详情页优化**：优化了书籍详情页面的简介文本显示效果。

#### 修复

* **状态防丢**：修复了设置界面中组件滑动到屏幕外后导致状态丢失的问题。
* **字体修复**：修复了自定义字体相关的若干 BUG。

## [v0.2.2] - 2026-03-04

### English

#### Added

* **Font Selection**: Added font selection support.
* **Status Bar**: Added a bottom status bar to display the current chapter title and reading progress.
* **Animation Toggle**: Added a toggle switch for page-turning animations.

#### Changed

* **UI Consistency**: Improved the visual consistency of theme color blocks between the settings interface and the reader's dropdown menu.
* **Book Compatibility**: Improved compatibility with custom page colors defined within books.
* **Footnote Support**: Enhanced parsing and support for various footnote formats.
* **Performance & Animations**: Added transition animations and optimized the rendering performance of the bookshelf.
* **Bottom Sheet Interactions**: Made the 'A' icons next to the zoom slider in the bottom sheet clickable for easier text size adjustment.
* **Optimized page-turning experience**

#### Fixed

* **Import Dialog**: Fixed a bug related to the import dialog not functioning correctly.
* **Home Page UI**: Fixed a UI issue where a blank white bar appeared at the bottom of the home page.
* **Link Interactions**: Fixed issues related to clicking internal and external links within the reader.

### Chinese

#### 新增

* **字体选择**：新增字体选择功能。
* **底部状态栏**：阅读器底部新增状态栏，可实时显示当前标题与阅读进度。
* **动画开关**：新增翻页动画的开启与关闭选项。

#### 变更与优化

* **界面一致性**：统一了设置界面和阅读器下拉菜单中主题方块的视觉样式。
* **兼容性提升**：更好地兼容了书籍自带的自定义页面颜色。
* **脚注支持**：增加对更多书籍脚注格式的兼容与支持。
* **性能与动效**：增加部分过渡动画，并优化了书架列表的显示性能。
* **交互优化**：Bottom Sheet 中缩放调节滑块两端的“A”图标现在支持直接点击调节。
* **优化翻页体验**

#### 修复

* **导入修复**：修复了书籍导入 Dialog 相关的 BUG。
* **界面修复**：去除了主页底部异常显示的白条。
* **链接修复**：修复了阅读器内链接点击的相关问题。


## [v0.2.1] - 2026-03-01

### English
#### Added
- Launched a new global theme system with independent light/dark mode switching.
- Added 6 new reading theme presets.
- New Settings Center (replacing "About") with centralized configs and licenses.
- Added support for Duokan-style footnotes.

#### Changed
- Redesigned library UI: optimized checkbox styles and selection colors.
- Improved UI consistency: updated dialogs, drawers, and toast colors across all themes.
- Enhanced EPUB parsing: improved cover detection and NAV/NCX path resolution.
- Optimized theme panel interactions.

#### Fixed
- Fixed font-size and line-height application issues in certain books.
- Improved tap accuracy for links in the reader.

### Chinese

#### 新增
- 上线全新全局主题系统，支持独立的明暗模式切换
- 新增 6 款阅读主题预设
- 新增设置中心（替代原“关于”页面），集成配置项及开源协议说明
- 新增对多看平台脚注格式的支持

#### 变更与优化
- 书架界面视觉重构：优化多选模式下的复选框样式与选中颜色表现；重构顶部与底部导航栏，并添加过渡动画
- 全面提升 UI 一致性：优化应用内弹窗、下拉抽屉、提示条、按钮边框及阴影色彩，确保在所有主题下的视觉协调性
- EPUB 解析逻辑升级：大幅提升书籍封面解析成功率及目录相对路径识别准确率
- 交互细节优化：优化主题面板的交互体验

#### 修复
- 修复部分书籍中字体大小和行高无法被正确应用的问题
- 提升正文阅读中链接点击的精确度