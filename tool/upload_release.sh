#!/usr/bin/env bash
# 发布上传脚本：生成 version.json 并上传 APK 到阿里云 OSS（国内分发）。
#
# 用法：
#   ./tool/upload_release.sh <tag> [bucket] [region]
# 示例：
#   ./tool/upload_release.sh v0.3.0 synlen cn-hangzhou
#
# 前置条件：
#   1. 已安装 ossutil（https://help.aliyun.com/zh/oss/developer-reference/install-ossutil）
#   2. 已配置 ossutil 凭证（ossutil config），或设置环境变量：
#      OSS_ACCESS_KEY_ID / OSS_ACCESS_KEY_SECRET / OSS_ENDPOINT
#   3. 本地已构建好 release APK（flutter build apk --release --split-per-abi 或 universal）
#
# 产物：
#   oss://<bucket>/version.json          —— 客户端检查更新用的版本元数据
#   oss://<bucket>/apk/synlen-<tag>-universal-release.apk
#   oss://<bucket>/apk/synlen-<tag>-<abi>-release.apk（存在则一并上传）
set -euo pipefail

TAG="${1:?用法: ./tool/upload_release.sh <tag> [bucket] [region]}"
BUCKET="${2:-synlen}"
REGION="${3:-cn-hangzhou}"
ENDPOINT="oss-${REGION}.aliyuncs.com"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# 从 tag 派生版本号与 buildNumber（规则与 CI 一致：vX.Y.Z → X*10000+Y*100+Z）
VERSION="${TAG#v}"
IFS='.' read -r MAJOR MINOR PATCH <<<"$VERSION"
BUILD_NUMBER=$((MAJOR * 10000 + MINOR * 100 + PATCH))

echo "==> 版本: $VERSION (build $BUILD_NUMBER)"

# 从 docs/user/release-notes.md 提取该版本段的更新日志（第一个 "## vx.y.z" 到下一个 "## " 之间）。
# 注：用 index() 字符串匹配而非正则，避免 BSD/GNU awk 对 \ 转义的行为差异。
UPDATE_LOG="$(
  awk -v ver="$VERSION" '
    index($0, "## v" ver) == 1 {in_section=1; next}
    in_section && index($0, "## ") == 1 {exit}
    in_section {print}
  ' "$ROOT/docs/user/release-notes.md"
)"
if [ -z "$UPDATE_LOG" ]; then
  echo "!! docs/user/release-notes.md 中未找到 v$VERSION 段：发版前先把「未发布」段改名为 ## v$VERSION（见 docs/cookbook/publishing-a-release.md），中止发布" >&2
  exit 1
fi

# 定位 universal APK 并计算 SHA-256（本地构建在 flutter-apk/，CI 会移动到 build/outputs/）。
# 摘要写进 version.json 的 androidApkSha256，客户端下载后比对，缺失时客户端放行（兼容旧清单）。
APK_DIR="$ROOT/build/app/outputs/flutter-apk"
OUTPUTS_DIR="$ROOT/build/outputs"
UNIVERSAL_APK="$APK_DIR/synlen-${TAG}-universal-release.apk"
if [ ! -f "$UNIVERSAL_APK" ]; then
  UNIVERSAL_APK="$APK_DIR/app-release.apk"
fi
if [ ! -f "$UNIVERSAL_APK" ]; then
  UNIVERSAL_APK="$OUTPUTS_DIR/synlen-${TAG}-universal-release.apk"
fi
if [ ! -f "$UNIVERSAL_APK" ]; then
  echo "!! 未找到 APK（已查找 $APK_DIR 与 $OUTPUTS_DIR），请先构建 release 包" >&2
  exit 1
fi
APK_SHA256="$(shasum -a 256 "$UNIVERSAL_APK" | awk '{print $1}')"
echo "==> APK SHA-256: $APK_SHA256"

# 组装 version.json（客户端协议见 check_update_tile.dart）
VERSION_JSON="$(
  python3 - "$MAJOR" "$MINOR" "$PATCH" "$BUILD_NUMBER" "$TAG" "$UPDATE_LOG" "$BUCKET" "$REGION" "$APK_SHA256" <<'PYEOF'
import json, sys
major, minor, patch, build, tag, update_log = (
    int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]),
    int(sys.argv[4]), sys.argv[5], sys.argv[6],
)
bucket, region, apk_sha256 = sys.argv[7], sys.argv[8], sys.argv[9]
base = f"https://{bucket}.oss-{region}.aliyuncs.com"
payload = {
    "code": 200,
    "data": {
        "majorNumber": major,
        "minorNumber": minor,
        "patchNumber": patch,
        "buildNumber": build,
        "updateLog": update_log.strip(),
        "lanzouUrl": "",
        "lanzouPassword": "",
        "githubUrl": f"https://github.com/Duskriver/Synlen/releases/tag/{tag}",
        "androidApkUrl": f"{base}/apk/synlen-{tag}-universal-release.apk",
        "androidApkSha256": apk_sha256,
        "iosAppStoreUrl": "",
    },
}
print(json.dumps(payload, ensure_ascii=False, indent=2))
PYEOF
)"
echo "$VERSION_JSON" > /tmp/synlen-version.json

echo "==> 上传 APK: $UNIVERSAL_APK"
ossutil cp -f "$UNIVERSAL_APK" \
  "oss://$BUCKET/apk/synlen-${TAG}-universal-release.apk" \
  -e "$ENDPOINT"

# 上传 split APK（若存在，同样兼容 CI 的 build/outputs/）
for abi in armeabi-v7a arm64-v8a x86_64; do
  SPLIT_APK="$APK_DIR/synlen-${TAG}-${abi}-release.apk"
  [ -f "$SPLIT_APK" ] || SPLIT_APK="$OUTPUTS_DIR/synlen-${TAG}-${abi}-release.apk"
  if [ -f "$SPLIT_APK" ]; then
    echo "==> 上传 split APK: $SPLIT_APK"
    ossutil cp -f "$SPLIT_APK" "oss://$BUCKET/apk/synlen-${TAG}-${abi}-release.apk" \
      -e "$ENDPOINT"
  fi
done

echo "==> 上传 version.json"
ossutil cp -f /tmp/synlen-version.json "oss://$BUCKET/version.json" \
  -e "$ENDPOINT"

echo ""
echo "==> 完成！version.json 内容："
echo "$VERSION_JSON"
echo ""
echo "客户端版本检查端点：https://$BUCKET.$ENDPOINT/version.json"
