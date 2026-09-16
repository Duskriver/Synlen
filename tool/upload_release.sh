#!/usr/bin/env bash
# 上传 ARM64 APK 到 Gitee，匿名校验成功后更新 version.json。
# 用法：./tool/upload_release.sh <vX.Y.Z> [owner/repo] [apk路径]
# 依赖 curl、jq、shasum；凭据使用 GITEE_TOKEN 或已登录的 Gitee CLI。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:?用法: ./tool/upload_release.sh <vX.Y.Z> [owner/repo] [apk路径]}"
REPO="${2:-Tang_Lei789/synlen}"
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo '版本必须是 vX.Y.Z' >&2; exit 1; }
MAJOR="${BASH_REMATCH[1]}" MINOR="${BASH_REMATCH[2]}" PATCH="${BASH_REMATCH[3]}"
# 与 Android versionCode 派生规则保持单调且不碰撞。
(( MAJOR <= 209999 && MINOR < 100 && PATCH < 100 )) || { echo '版本超出构建号范围' >&2; exit 1; }
BUILD_NUMBER=$((MAJOR * 10000 + MINOR * 100 + PATCH))
[[ "$REPO" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ ]] || { echo '仓库格式必须是 owner/repo' >&2; exit 1; }
APK="${3:-$ROOT/build/outputs/synlen-${TAG}-arm64-release.apk}"
if [[ $# -lt 3 && ! -f "$APK" ]]; then APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"; fi
[[ -f "$APK" ]] || { echo "未找到 APK: $APK" >&2; exit 1; }
APK_NAME="$(basename "$APK")"
[[ "$APK_NAME" =~ ^[A-Za-z0-9._-]+\.apk$ ]] || { echo 'APK 文件名只能包含英文字母、数字、点、横线和下划线' >&2; exit 1; }
UPDATE_LOG="$(awk -v heading="## $TAG" '$0 == heading {found=1; next} found && /^## / {exit} found {print}' "$ROOT/docs/user/release-notes.md")"
[[ -n "$UPDATE_LOG" ]] || { echo "release-notes.md 中缺少 $TAG 段" >&2; exit 1; }
APK_SHA256="$(shasum -a 256 "$APK" | awk '{print $1}')"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
umask 077
if [[ -z "${GITEE_TOKEN:-}" ]]; then
  GITEE_TOKEN="$(gitee auth token)"
fi
[[ -n "$GITEE_TOKEN" && "$GITEE_TOKEN" != *$'\n'* && "$GITEE_TOKEN" != *'"'* && "$GITEE_TOKEN" != *'\'* ]] || { echo 'Gitee 凭据无效' >&2; exit 1; }
printf 'header = "Authorization: Bearer %s"\n' "$GITEE_TOKEN" > "$WORK/auth"
unset GITEE_TOKEN
API="https://gitee.com/api/v5/repos/$REPO"
# 授权仅发送给 API；下载使用匿名请求，绝不携带令牌跟随重定向。
api() { curl --config "$WORK/auth" -sS --fail-with-body --connect-timeout 15 --max-time 300 "$@"; }
get_optional() {
  local status
  status="$(curl --config "$WORK/auth" -sS --connect-timeout 15 --max-time 30 -o "$2" -w '%{http_code}' "$1")"
  case "$status" in 200) return 0 ;; 404) return 1 ;; *) echo "Gitee 请求失败: HTTP $status" >&2; exit 1 ;; esac
}
api "$API" > "$WORK/repo.json"
jq -e '.public == true' "$WORK/repo.json" >/dev/null || { echo '分发仓库必须公开' >&2; exit 1; }
BRANCH=updates
CONTENTS="$API/contents/version.json"
METHOD=POST
if get_optional "$CONTENTS?ref=$BRANCH" "$WORK/contents.json" && ! jq -e '. == []' "$WORK/contents.json" >/dev/null; then
  METHOD=PUT
  jq -r '.content' "$WORK/contents.json" | tr -d '\n' | base64 --decode > "$WORK/previous.json"
  jq -e --argjson build "$BUILD_NUMBER" '.code == 200 and (.data.buildNumber <= $build)' "$WORK/previous.json" >/dev/null || { echo '拒绝降级或覆盖无效清单' >&2; exit 1; }
fi
if ! get_optional "$API/releases/tags/$TAG" "$WORK/release.json"; then
  jq -n --arg tag "$TAG" --arg body "$UPDATE_LOG" --arg branch "$TAG" '{tag_name:$tag,name:$tag,body:$body,target_commitish:$branch,prerelease:false}' > "$WORK/release-request.json"
  api -X POST -H 'Content-Type: application/json' --data-binary "@$WORK/release-request.json" "$API/releases" > "$WORK/release.json"
fi
RELEASE_ID="$(jq -er '.id' "$WORK/release.json")"
APK_URL="$(jq -r --arg name "$APK_NAME" '.assets[]? | select(.name == $name) | .browser_download_url' "$WORK/release.json")"
if [[ -z "$APK_URL" ]]; then
  api -F "file=@$APK" "$API/releases/$RELEASE_ID/attach_files" > "$WORK/attachment.json"
  APK_URL="$(jq -er '.browser_download_url' "$WORK/attachment.json")"
fi
[[ "$APK_URL" == https://* ]] || { echo 'APK 地址必须是 HTTPS' >&2; exit 1; }
curl -fLsS --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 300 "$APK_URL" -o "$WORK/verify.apk"
REMOTE_SHA256="$(shasum -a 256 "$WORK/verify.apk" | awk '{print $1}')"
[[ "$APK_SHA256" == "$REMOTE_SHA256" ]] || { echo '远端 APK 摘要不匹配；拒绝更新清单或覆盖已发布附件' >&2; exit 1; }
jq -n --argjson major "$MAJOR" --argjson minor "$MINOR" --argjson patch "$PATCH" --argjson build "$BUILD_NUMBER" --arg log "$UPDATE_LOG" --arg tag "$TAG" --arg url "$APK_URL" --arg sha "$APK_SHA256" '{code:200,data:{majorNumber:$major,minorNumber:$minor,patchNumber:$patch,buildNumber:$build,updateLog:($log|gsub("^\\s+|\\s+$";"")),androidApkUrl:$url,androidApkSha256:$sha,githubUrl:("https://github.com/Duskriver/Synlen/releases/tag/"+$tag),lanzouUrl:"",lanzouPassword:"",iosAppStoreUrl:""}}' > "$WORK/version.json"
# 同一版本只允许重试完全相同的安装包。
if [[ -f "$WORK/previous.json" ]]; then
  jq -e --argjson build "$BUILD_NUMBER" --arg sha "$APK_SHA256" '.data.buildNumber != $build or .data.androidApkSha256 == $sha' "$WORK/previous.json" >/dev/null || { echo '同一构建号不能替换 APK' >&2; exit 1; }
fi
CONTENT="$(base64 < "$WORK/version.json" | tr -d '\n')"
SHA="$(jq -r '.sha // ""' "$WORK/contents.json" 2>/dev/null || true)"
jq -n --arg content "$CONTENT" --arg sha "$SHA" --arg branch "$BRANCH" --arg message "发布 $TAG 更新清单" '{content:$content,branch:$branch,message:$message} + (if $sha == "" then {} else {sha:$sha} end)' > "$WORK/manifest-request.json"
api -X "$METHOD" -H 'Content-Type: application/json' --data-binary "@$WORK/manifest-request.json" "$CONTENTS" > "$WORK/result.json"
ENDPOINT="https://gitee.com/$REPO/raw/$BRANCH/version.json"
curl -fLsS --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 30 "$ENDPOINT" -o "$WORK/public.json"
diff -u <(jq -S . "$WORK/version.json") <(jq -S . "$WORK/public.json")
mkdir -p "$ROOT/build/outputs"
cp "$WORK/version.json" "$ROOT/build/outputs/version.json"
echo "已发布并匿名验证：$ENDPOINT"
echo "APK SHA-256: $APK_SHA256"
