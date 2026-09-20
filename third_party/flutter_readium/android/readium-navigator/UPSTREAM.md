# Readium Navigator 本地源码模块

本目录固定为 [Readium Kotlin Toolkit 3.3.0](https://github.com/readium/kotlin-toolkit/tree/3.3.0/readium/navigator) 的 Android Navigator。只保留此模块的源码、资源、测试、PhotoView JAR 和构建配置，省略 `src/main/assets/_scripts/` 开发工具；运行脚本与 CSS 均为上游生成物。Shared、Streamer 及其余 Readium 组件继续使用官方 Maven 3.3.0。源码许可证见 [LICENSE](LICENSE)，随应用分发的组合许可见 [插件 NOTICES](../../NOTICES)。

## 固定来源

| 内容 | 来源 | SHA-256 |
|---|---|---|
| SDK 标签归档 | [3.3.0.tar.gz](https://github.com/readium/kotlin-toolkit/archive/refs/tags/3.3.0.tar.gz) | `fef17d4d9b05fa5345d7e296b7ffcec43e76a84727fe1f9d3ba406ca40c7ce16` |
| 官方 Navigator AAR | [readium-navigator-3.3.0.aar](https://repo.maven.apache.org/maven2/org/readium/kotlin-toolkit/readium-navigator/3.3.0/readium-navigator-3.3.0.aar) | `d102af0830de2a79ca1e483f5ef14674469b732f95a8abcf74afe993d9dad53c` |
| 官方源码包 | [readium-navigator-3.3.0-sources.jar](https://repo.maven.apache.org/maven2/org/readium/kotlin-toolkit/readium-navigator/3.3.0/readium-navigator-3.3.0-sources.jar) | `a2057c8029434a770bde39d00f4e747c0f9e1b0f1b0c8e191723595368ee2932` |
| PhotoView JAR | 标签归档内 `readium/navigator/libs/PhotoView-2.3.0.jar` | `6e2aa188c6fd45d0869fe51d86de32affa377b44ae56e555304cd5ab5eaf2b44` |

标签内的 68 个 Kotlin 运行文件与 Maven 源码包逐文件一致；25 个运行资产与官方 AAR 逐文件一致。PhotoView JAR 与 AAR 内嵌 JAR 的 ZIP 元数据不同，22 个条目内容一致。

## 本地差异与构建

[补丁](SYNlen.patch) 只包含 3 个文件：独立模块构建配置、`R2WebView.kt` 和 `R2WebViewDragTest.kt`。构建配置固定官方 POM 中的运行依赖版本，保留资源、ViewBinding、BuildConfig 和上游 Kotlin 编译选项；测试使用 Robolectric 4.16.1。应用将所有 `org.readium.kotlin-toolkit:readium-navigator` 依赖替换为本模块，避免同时打包 Maven 版本。

触摸修补仅作用于分页模式下原速度判定未落页的拖动：单指、水平主导、净位移达到视口宽度的四分之一，且外层页面确实同向移动四分之一页，才沿 SDK 原导航路径完成一页。资源边界须有原生外层触边回调；表格内部滚动本身不满足外层位移条件。多指和取消终止位移补充判定，短拖与回撤不进入位移补充判定。原快速甩动、分页排版、动画、RTL 和跨章节导航继续由 SDK 处理。

在仓库根目录执行 `bash tool/test_readium_android.sh` 验证模块测试；构建环境须使用 JDK 21。真机还须验证停顿后抬手、双向跨章节和内部图表滚动，Robolectric 只重放 Chromium 的外层滚动结果。

## 重建源码

在临时目录下载并校验上述标签归档，解压后复制 `readium/navigator/`，删除其中的 `src/main/assets/_scripts/`，再将 SDK 根 `LICENSE` 复制到模块根。在这个干净模块目录执行 `patch -p1 < SYNlen.patch`。此过程不需要重新编译上游 Web 脚本；若从 AAR 提取 `assets/` 做交叉校验，应保持每个运行资产字节一致。`UPSTREAM.md` 和 `SYNlen.patch` 是维护资料，不参与源码重放。

外层 [flutter_readium 补丁](../../SYNlen.patch) 不包含此目录；重建插件后，须单独按本节还原此模块，并保留应用的 Gradle project include。升级 Readium 时，应重新核对标签、Maven 源码与运行资产，再重放补丁和手势测试。

## Dev Note

None.
