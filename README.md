# 词镜

<p align="center">
  <img src="docs/icon.png" width="128" alt="词镜图标" />
</p>

词镜是一个基于 Flutter 开发的英语学习阅读器，支持 Android 和 iOS。通过阅读英文原书学英语：点击单词查看音标与释义，长按句子获取翻译与语法分析。

[![Flutter](https://img.shields.io/badge/Flutter-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey.svg)]()

## 功能

- 支持 EPUB 2.0 / 3.0 与 TXT
- 书架分组与整理、阅读主题与排版设置
- 目录导航、脚注、图片预览
- 点击单词：词典发音、音标、直译、常见用法与句中含义（DeepSeek，用户自填密钥）
- 长按句子：翻译与语法分析、整句朗读（TTS 回退）
- 书库备份与恢复（单文件 ZIP，经系统分享面板导出）

## 开始使用

用户指南见 [docs/user/index.md](docs/user/index.md)。自行构建：

```sh
flutter pub get
flutter run
flutter build apk --release
flutter build ios --release
```

## 文档

- 用户指南：[docs/user/index.md](docs/user/index.md) · 版本记录：[docs/user/release-notes.md](docs/user/release-notes.md)
- 架构：[docs/architecture.md](docs/architecture.md) · 术语：[docs/glossary.md](docs/glossary.md)
- 贡献者：[docs/development.md](docs/development.md) · Agent 入口：[AGENTS.md](AGENTS.md)

## 说明

- Flutter SDK >= 3.38.0（推荐 3.44.9 stable）；Dart SDK >= 3.10.8（推荐 3.12.2 stable）。
- 本项目自有代码以 [MIT](./LICENSE) 发布；上游项目的 MIT 许可证保留在 [assets/licenses/lumina_mit.txt](./assets/licenses/lumina_mit.txt) 中，并已接入应用内"开源许可证"页面。MIT 仅覆盖项目自有代码，第三方依赖（如 flutter_sound 的 MPL-2.0）各自保留其许可证。
