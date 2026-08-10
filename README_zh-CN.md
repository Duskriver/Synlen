# 词镜

<p align="center">
  <img src="docs/icon.png" width="128" alt="词镜图标" />
</p>

词镜是一个基于 Flutter 开发的轻量级 EPUB 阅读器，支持 Android 和 iOS。

[![Flutter](https://img.shields.io/badge/Flutter-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey.svg)]()

[CHANGELOG](./CHANGELOG.md)

## 功能特性

- 支持 EPUB 2.0 / 3.0
- 书架分组与整理
- 阅读主题与排版设置
- 目录导航、脚注、图片预览
- 书库备份与恢复

## 快速开始

克隆仓库：

```bash
git clone https://github.com/Duskriver/Synlen.git
cd Synlen
```

安装依赖：

```bash
flutter pub get
```

运行应用：

```bash
# 学习功能需要 API Key（单词解释/句子分析 + TTS 朗读），未配置时相应功能会提示不可用
flutter run --dart-define=DEEPSEEK_API_KEY=你的key --dart-define=ALIYUN_TTS_API_KEY=你的key
```

构建发布包：

```bash
# 发布包同样需要注入 API Key，否则学习功能不可用
flutter build apk --release --dart-define=DEEPSEEK_API_KEY=你的key --dart-define=ALIYUN_TTS_API_KEY=你的key
flutter build ios --release --dart-define=DEEPSEEK_API_KEY=你的key --dart-define=ALIYUN_TTS_API_KEY=你的key
```

> API Key 通过编译期 `--dart-define` 注入，不会写进源码或产物文件之外。CI 发布构建使用 GitHub Secrets 注入（见 `.github/workflows/build_release.yml`）。

## 说明

- Flutter SDK >= 3.38.0（推荐 3.44.9 stable）
- Dart SDK >= 3.10.8（推荐 3.12.2 stable）
- 上游 MIT 许可证保留在 [LICENSE](./LICENSE) 中，并已接入应用内“开源许可证”页面
