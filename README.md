# 词镜

<p align="center">
  <img src="docs/icon.png" width="128" alt="词镜 icon" />
</p>

词镜 is a lightweight EPUB reader built with Flutter for Android and iOS.

[![Flutter](https://img.shields.io/badge/Flutter-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-lightgrey.svg)]()

[CHANGELOG](./CHANGELOG.md)

## Features

- EPUB 2.0 / 3.0 reading
- Bookshelf management and grouping
- Reader theme and typography controls
- Footnotes, image preview, and TOC navigation
- Library backup and restore

## Quick Start

Clone the repository:

```bash
git clone https://github.com/Duskriver/Synlen.git
cd Synlen
```

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Build release packages:

```bash
flutter build apk --release
flutter build ios --release
```

### AI Service API Keys (optional)

Word explanation, sentence analysis and TTS reading need API keys from **DeepSeek** and **Aliyun TTS**. **Keys are entered by the user inside the app** (Settings → AI Service) and stored in the system secure storage (Keychain / Keystore). No key is ever embedded in source code or build artifacts — this project ships open-source without any bundled keys.

### In-app updates

- Update checks read `version.json` from Aliyun OSS (fast in mainland China)
- Android: downloads and installs the APK directly from OSS (no GitHub access needed)
- iOS: opens the App Store page (available after App Store release)
- Publishing a new version: build the release then run `./tool/upload_release.sh <tag> [bucket] [region]`, or let CI build on tag push and optionally upload to OSS

## Notes

- Flutter SDK >= 3.38.0（推荐 3.44.9 stable）
- Dart SDK >= 3.10.8（推荐 3.12.2 stable）
- The original MIT license is kept in [LICENSE](./LICENSE) and is also shown inside the app's Open Source Licenses page.
