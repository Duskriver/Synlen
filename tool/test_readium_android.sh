#!/usr/bin/env bash
# 执行 Readium 与 OTA 的原生单元测试；调用前先运行 flutter pub get 生成本机配置。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail() { echo "$*" >&2; exit 1; }
[[ -f android/local.properties ]] || fail '缺少 android/local.properties，请先运行 flutter pub get'

# fresh clone 不包含 wrapper；复用固定 Flutter SDK 自带文件，保留仓库锁定的 Gradle 版本。
if [[ ! -f android/gradlew || ! -f android/gradle/wrapper/gradle-wrapper.jar ]]; then
  FLUTTER_SDK_PATH="$(sed -n 's/^flutter.sdk=//p' android/local.properties)"
  [[ -n "$FLUTTER_SDK_PATH" ]] || fail 'android/local.properties 缺少 flutter.sdk，请重新运行 flutter pub get'
  WRAPPER_SOURCE="$FLUTTER_SDK_PATH/bin/cache/artifacts/gradle_wrapper"
  [[ -f "$WRAPPER_SOURCE/gradlew" && -f "$WRAPPER_SOURCE/gradle/wrapper/gradle-wrapper.jar" ]] || fail 'Flutter SDK 缺少 Gradle wrapper，请运行 flutter precache --universal'
  mkdir -p android/gradle/wrapper
  [[ -f android/gradlew ]] || cp "$WRAPPER_SOURCE/gradlew" android/gradlew
  [[ -f android/gradle/wrapper/gradle-wrapper.jar ]] || cp "$WRAPPER_SOURCE/gradle/wrapper/gradle-wrapper.jar" android/gradle/wrapper/gradle-wrapper.jar
fi
cd android
bash ./gradlew --no-daemon :synlen_readium_navigator:testDebugUnitTest :flutter_readium:testDebugUnitTest :ota_update:testDebugUnitTest
