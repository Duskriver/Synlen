# 词镜

<p align="center">
  <img src="docs/icon.png" width="128" alt="词镜图标" />
</p>

词镜是一个基于 Flutter 开发的英语学习阅读器，支持 Android 和 iOS。通过阅读
英文原书学英语：点击单词查看音标与释义，长按句子获取翻译与语法分析。

[![Flutter](https://img.shields.io/badge/Flutter-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey.svg)]()

[CHANGELOG](./CHANGELOG.md)

## 功能特性

- 支持 EPUB 2.0 / 3.0 与 TXT
- 书架分组与整理
- 阅读主题与排版设置
- 目录导航、脚注、图片预览
- 点击单词：词典发音、音标、直译、常见用法与句中含义（DeepSeek，用户自填密钥）
- 长按句子：翻译与语法分析、整句朗读（TTS 回退）
- 书库备份与恢复（单文件 ZIP，经系统分享面板导出）

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
flutter run
```

构建发布包：

```bash
flutter build apk --release
flutter build ios --release
```

### AI 服务 API Key（可选）

单词解释、句子分析、TTS 朗读功能需要 **DeepSeek** 与**阿里云 TTS** 的 API Key。**Key 由使用者在 App 内自行填写**（设置 → AI 服务），存于系统安全存储（Keychain / Keystore）。源码与构建产物**不含任何密钥**，本项目开源分发不附带 Key——这也是开源的先决条件。

### 应用内更新

- 检查更新读取阿里云 OSS 上的 `version.json`（国内网络可达）
- Android：应用内直接下载 APK 并安装（OSS 分发，无需访问 GitHub）
- iOS：跳转 App Store 更新（上架后生效）
- 发布新版本：构建 release 包后执行 `./tool/upload_release.sh <tag> [bucket] [region]`，或依赖 CI 打 tag 自动构建 + 可选自动上传 OSS

## 说明

- Flutter SDK >= 3.38.0（推荐 3.44.9 stable）
- Dart SDK >= 3.10.8（推荐 3.12.2 stable）
- 本项目自有代码以 [MIT](./LICENSE) 发布；上游项目的 MIT 许可证保留在
  [assets/licenses/lumina_mit.txt](./assets/licenses/lumina_mit.txt) 中，并已接入应用内“开源许可证”页面。
  MIT 仅覆盖项目自有代码，第三方依赖（如 flutter_sound 的 MPL-2.0）各自保留其许可证。
