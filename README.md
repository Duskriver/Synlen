# 词镜

<p align="center">
  <img src="assets/icons/icon_opaque.png" width="128" alt="词镜图标" />
</p>

词镜是一个基于 Flutter 开发的英语学习阅读器，当前发布 Android ARM64 安装包。通过阅读英文原书学英语：点击单词查看音标与释义，长按句子获取翻译与语法分析。

[![Flutter](https://img.shields.io/badge/Flutter-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20ARM64-lightgrey.svg)]()

## 功能

- 支持 EPUB 2.0 / 3.0 与 TXT
- 书架分组与整理、阅读主题与排版设置
- 目录导航、脚注、图片预览
- 点击单词：词典发音、音标、直译、常见用法与句中含义（DeepSeek，用户自填密钥）
- 长按句子：翻译与语法分析、整句朗读（TTS 回退）
- 书库备份与恢复（单文件 ZIP，经系统分享面板导出）

## 开始使用

下载安装包：[Gitee 发行版](https://gitee.com/Tang_Lei789/synlen/releases) · [GitHub 发行版](https://github.com/Duskriver/Synlen/releases)。用户指南见 [docs/user/index.md](docs/user/index.md)。自行构建：

```sh
flutter pub get
flutter run
flutter build apk --release --target-platform android-arm64
```

## 源码与贡献

[GitHub](https://github.com/Duskriver/Synlen) 是主仓库，[Gitee](https://gitee.com/Tang_Lei789/synlen) 自动同步源码与发行包。请在 GitHub 提交 issue 和 PR。

## 文档

- 用户指南：[docs/user/index.md](docs/user/index.md) · 版本记录：[docs/user/release-notes.md](docs/user/release-notes.md)
- 架构：[docs/architecture.md](docs/architecture.md) · 模块设计：[docs/design.md](docs/design.md) · 术语：[docs/glossary.md](docs/glossary.md)
- 贡献者：[docs/development.md](docs/development.md) · Agent 入口：[AGENTS.md](AGENTS.md)

## 说明

- Flutter SDK >= 3.44.8（推荐 3.44.9 stable）；Dart SDK >= 3.10.8（推荐 3.12.2 stable）。
- 本项目自有代码以 [MIT](./LICENSE) 发布；上游项目的 MIT 许可证保留在 [assets/licenses/lumina_mit.txt](./assets/licenses/lumina_mit.txt) 中，并已接入应用内"开源许可证"页面。MIT 仅覆盖项目自有代码，第三方依赖（如 flutter_sound 的 MPL-2.0）各自保留其许可证。
