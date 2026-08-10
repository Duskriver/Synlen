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
# Learning features need API keys (word explanation / sentence analysis / TTS reading).
# Without them those features will show an "unavailable" message.
flutter run --dart-define=DEEPSEEK_API_KEY=your_key --dart-define=ALIYUN_TTS_API_KEY=your_key
```

Build release packages:

```bash
# Release builds need the same API keys injected, otherwise learning features won't work.
flutter build apk --release --dart-define=DEEPSEEK_API_KEY=your_key --dart-define=ALIYUN_TTS_API_KEY=your_key
flutter build ios --release --dart-define=DEEPSEEK_API_KEY=your_key --dart-define=ALIYUN_TTS_API_KEY=your_key
```

> API keys are injected at compile time via `--dart-define` and are never stored in source code. CI release builds use GitHub Secrets (see `.github/workflows/build_release.yml`).

## Notes

- Flutter SDK >= 3.38.0（推荐 3.44.9 stable）
- Dart SDK >= 3.10.8（推荐 3.12.2 stable）
- The original MIT license is kept in [LICENSE](./LICENSE) and is also shown inside the app's Open Source Licenses page.
