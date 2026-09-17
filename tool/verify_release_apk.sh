#!/usr/bin/env bash
# 发布前验证 Android 元数据与正式签名；不读取签名私钥。
set -euo pipefail
TAG="${1:?用法: verify_release_apk.sh <vX.Y.Z> <apk路径>}"
APK="${2:?需要 APK 路径}"
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo '版本必须是 vX.Y.Z' >&2; exit 1; }
MAJOR="${BASH_REMATCH[1]}" MINOR="${BASH_REMATCH[2]}" PATCH="${BASH_REMATCH[3]}"
(( MAJOR <= 209999 && MINOR < 100 && PATCH < 100 )) || { echo '版本超出构建号范围' >&2; exit 1; }
BUILD_NUMBER=$((MAJOR * 10000 + MINOR * 100 + PATCH))
[[ -f "$APK" ]] || { echo "未找到 APK: $APK" >&2; exit 1; }
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
TOOLS=''
for candidate in "$SDK"/build-tools/*; do
  if [[ -x "$candidate/aapt" && -x "$candidate/apksigner" ]]; then TOOLS="$candidate"; fi
done
[[ -n "$SDK" && -n "$TOOLS" ]] || { echo '请设置 ANDROID_HOME 并安装 Android SDK Build-Tools' >&2; exit 1; }
BADGING="$("$TOOLS/aapt" dump badging "$APK")"
PACKAGE="$(printf '%s\n' "$BADGING" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
VERSION="$(printf '%s\n' "$BADGING" | sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p")"
CODE="$(printf '%s\n' "$BADGING" | sed -n "s/^package: .*versionCode='\([^']*\)'.*/\1/p")"
[[ "$PACKAGE" == com.tanglei.synlen && "$VERSION" == "${TAG#v}" && "$CODE" == "$BUILD_NUMBER" ]] || { echo 'APK 包名、版本号或构建号与发布版本不一致' >&2; exit 1; }
ABIS="$(unzip -Z -1 "$APK" | awk -F/ '$1 == "lib" && NF == 3 && $3 ~ /[.]so$/ {print $2}' | sort -u)"
[[ "$ABIS" == arm64-v8a ]] || { echo 'APK 必须只包含 ARM64 原生库' >&2; exit 1; }
CERTS="$("$TOOLS/apksigner" verify --print-certs "$APK")"
FINGERPRINT="$(printf '%s\n' "$CERTS" | sed -n 's/^Signer #[0-9]* certificate SHA-256 digest: //p' | tr '[:upper:]' '[:lower:]')"
# 已发布正式包的证书摘要，防止 Gradle 回退到 debug 签名后被上传。
[[ "$FINGERPRINT" == aaecfc6b98149129dfb674117b663af6cd524e34b3dd7af8ad0a3c87bc3d21ff ]] || { echo 'APK 签名与正式发布证书不一致' >&2; exit 1; }
echo "APK 校验通过：${TAG}+${BUILD_NUMBER}，ARM64，正式签名"
