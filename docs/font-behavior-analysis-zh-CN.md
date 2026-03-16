# Synlen 字体机制调查说明

本文档整理 Synlen 当前与字体相关的实现，供后续开发、排查问题或让其他 AI 接手时快速建立上下文。

## 1. 结论摘要

- App 界面字体和阅读器书籍正文字体是两套独立机制。
- App 界面当前没有配置项目自带字体，默认使用系统字体。
- 阅读器正文默认优先使用 EPUB 自己声明或内嵌的字体。
- 阅读器已经支持导入自定义字体，并可选择是否强制覆盖书籍字体。
- 更换 App 界面字体，不会自动更换书里的字体。
- 更换阅读器自定义字体，不会直接影响单词分析和句子分析的数据、缓存和业务流程。
- 更换阅读器字体会影响排版和分页，因此页数、页码、点击落点附近的排版表现可能变化，但分析功能本身仍应可用。

## 2. 当前默认字体是什么

### 2.1 App 界面默认字体

当前 `MaterialApp` 使用的是应用主题，但主题中没有显式设置 `fontFamily`，项目也没有在 `pubspec.yaml` 中声明 `flutter/fonts`。

因此：

- App 的设置页、书架页、弹窗、分析弹窗等 Flutter 界面，默认使用系统字体。
- 不同平台上的实际字体可能不同，例如 Android 和 iOS 的默认字体回退链不同。

关键代码：

- `lib/src/app.dart`
- `lib/src/core/theme/app_theme.dart`
- `pubspec.yaml`

### 2.2 阅读器书籍正文默认字体

阅读器默认的 `ReaderSettings.fontFileName` 为 `null`，代码注释明确说明这表示“使用 epub 自己的字体”。

因此：

- 如果书里自带字体或 CSS 写了 `font-family`，阅读器默认会尽量遵循书籍自己的排版。
- 如果书里没有有效字体声明，则最终会回退到 WebView / 系统可用字体。
- 项目还对部分多看系字体名做了本地映射，例如 `DK-SONGTI`、`DK-HEITI`、`DK-KAITI` 等。

关键代码：

- `lib/src/features/reader/domain/reader_settings.dart`
- `web_assets/pagination.css/_font.css`
- `web_assets/controller.js/renderer/theme_manager.ts`

## 3. 字体机制分层

可以把字体理解成以下两层。

### 3.1 Flutter UI 层

这层负责：

- 书架
- 设置页
- 控件面板
- 单词解释弹窗
- 句子分析弹窗

这层走 `ThemeData` 和 `TextTheme`，与 EPUB WebView 正文不是同一套渲染。

### 3.2 Reader WebView 层

这层负责：

- EPUB 章节正文
- HTML/CSS 排版
- 自定义阅读字体
- 是否覆盖书籍原始字体

这层通过 `EpubTheme` 把 `fontFileName` 和 `overrideFontFamily` 传给前端注入脚本，再由 WebView 内的 CSS 生效。

关键代码链路：

1. `ReaderSettings.toEpubTheme()`
2. `generateSkeletonHtml()` 注入主题配置
3. `ThemeManager.generateVariableStyle()` 生成 `@font-face` 和 CSS 变量
4. `_font.css` 根据 class 决定是否覆盖正文 `font-family`

关键代码：

- `lib/src/features/reader/domain/reader_settings.dart`
- `lib/src/features/reader/domain/epub_theme.dart`
- `lib/src/features/reader/data/reader_scripts.dart`
- `web_assets/controller.js/renderer/theme_manager.ts`
- `web_assets/pagination.css/_font.css`

## 4. 现在该怎么更换字体

### 4.1 如果要更换 App 全局界面字体

需要改 Flutter 主题，而不是阅读器设置。

典型改法：

1. 在 `pubspec.yaml` 里声明字体资源。
2. 在 `ThemeData` 或 `textTheme.apply()` 中设置 `fontFamily`。
3. 重新构建 App。

这种改法影响的是 Flutter UI，不直接影响 EPUB 正文。

### 4.2 如果要更换阅读器中的书籍字体

当前项目已经支持，无需先新增架构。

现有流程：

1. 在设置页导入 `.ttf` 或 `.otf` 字体文件。
2. 字体文件会被复制到应用文档目录下的 `fonts` 目录。
3. 阅读器样式面板中会显示可选字体。
4. 用户可选择某个导入字体，并决定是否开启“覆盖书籍字体”。

关键代码：

- `lib/src/features/settings/presentation/widgets/settings_font_section.dart`
- `lib/src/features/settings/application/font_manager_notifier.dart`
- `lib/src/features/reader/presentation/widgets/reader_font_selector.dart`

## 5. “换了以后书里的字体会不会变”

答案要分情况。

### 5.1 只改 App 主题字体

不会自动改变书里的正文。

原因：

- App 字体走 Flutter。
- 书籍字体走 WebView + 注入 CSS。
- 两者渲染通路独立。

### 5.2 在阅读器里选择了自定义字体，但没有开启“覆盖书籍字体”

书里的字体可能部分变化，也可能很多地方不变。

原因：

- 代码只给 `body` 设置字体。
- 如果书中具体元素自己声明了 `font-family`，那些规则仍可能优先生效。

对应 CSS：

- `body.synlen-override-font { font-family: var(--synlen-font-family, inherit); }`

### 5.3 在阅读器里选择了自定义字体，并开启“覆盖书籍字体”

书里的大多数正文都会变成你选定的字体。

原因：

- 项目会给 `body` 和 `body *` 强制加上 `font-family: ... !important`。
- 这会压过绝大多数书籍自身的字体声明。

对应 CSS：

- `body.synlen-force-override-font, body.synlen-force-override-font * { font-family: ... !important; }`

## 6. 对单词分析和句子分析有没有影响

## 6.1 对业务数据和缓存基本没有影响

单词解释和句子分析的缓存键来自文本内容，不来自字体。

- 单词缓存依赖 `word + context`
- 句子缓存依赖 `sentence`

因此更换字体后：

- 已有缓存不会失效
- 已有分析结果不会被重算
- 音频缓存路径逻辑也不会因为字体变化而变化

关键代码：

- `lib/src/features/learning/data/repositories/word_repository.dart`
- `lib/src/features/learning/data/repositories/sentence_repository.dart`

## 6.2 对分析弹窗的显示字体通常没有影响

单词解释弹窗和句子分析弹窗是 Flutter 组件，不是 WebView 正文的一部分。

它们的正文显示使用的是：

- `Theme.of(context).textTheme.bodyMedium`
- `MarkdownBody`

所以：

- 你只改阅读器书体时，分析弹窗一般不会跟着改变字体。
- 只有你改 Flutter 全局主题字体时，这些弹窗才会跟着变化。

关键代码：

- `lib/src/features/learning/presentation/widgets/word_definition_dialog.dart`
- `lib/src/features/learning/presentation/widgets/sentence_analysis_dialog.dart`

## 6.3 对交互体验存在间接影响，但不是功能性破坏

点词和选句依赖 WebView 中文本范围提取：

- 通过点击坐标取得 `Range`
- 扩展为单词或句子
- 再把文本发回 Flutter

这套逻辑主要依赖 DOM 文本，而不是某个固定字体。

因此通常不会因为更换字体而“功能失效”。但字体变化会导致：

- 字宽变化
- 换行变化
- 分页变化
- 某些点击位置对应的字符发生轻微偏移

所以更准确的说法是：

- 功能本身不受字体配置耦合
- 但排版重流后，点击体验和分页结果会发生自然变化

关键代码：

- `web_assets/controller.js/renderer/interaction.ts`
- `web_assets/controller.js/renderer/renderer.ts`
- `lib/src/features/reader/presentation/reader_screen.dart`

## 7. 字体变化时阅读器内部会发生什么

当字体设置变化时：

1. `ReaderSettings` 更新
2. `ReaderScreen` 监听到 `fontFileName` 或 `overrideFontFamily` 变化
3. WebView 主题更新
4. 新的字体配置被注入到 iframe 文档
5. 页面重新排版并重新计算分页与交互映射

这解释了为什么改字体后，阅读器页数和位置可能变化。

关键代码：

- `lib/src/features/reader/presentation/reader_screen.dart`
- `web_assets/controller.js/renderer/theme_manager.ts`
- `web_assets/controller.js/renderer/renderer.ts`

## 8. 后续如果要改代码，建议分两类处理

### 8.1 目标是“统一 App 所有 Flutter 页面字体”

建议只改：

- `pubspec.yaml`
- `lib/src/core/theme/app_theme.dart`

不要误改阅读器 WebView 注入逻辑。

### 8.2 目标是“统一书籍正文显示字体”

建议只改：

- 阅读器字体选择逻辑
- WebView 注入 CSS
- 是否覆盖书籍字体的策略

不要误以为改 `ThemeData.fontFamily` 就能控制 EPUB 正文。

## 9. 风险提示

- 强制覆盖书籍字体后，某些精细排版书籍的视觉风格可能被破坏。
- 特殊字体可能缺字，导致方块字或 fallback 混排。
- 字体变化会造成分页变化，因此“当前页”感知会和旧字体不一致。
- 如果导入字体只覆盖拉丁字符、不覆盖中文字符，实际显示可能变成中英混合回退。

## 10. 一句话判断规则

- 想改“设置页、弹窗、按钮”的字体，改 Flutter 主题。
- 想改“书里正文”的字体，改阅读器自定义字体 / WebView 字体注入。
- 想让书里几乎全部跟着变，必须开启覆盖书籍字体。
- 单词分析和句子分析的数据逻辑不依赖字体，但阅读排版和点击落点会随字体变化而变化。

