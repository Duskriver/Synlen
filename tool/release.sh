#!/usr/bin/env bash
# 本地与手动云构建共用的发布入口；仅在全部门禁通过后写入远端。
set -euo pipefail
usage() {
  echo '用法: ./tool/release.sh <vX.Y.Z> [--prepare-only] [--apk <路径>]'
  echo '默认检查、构建并发布；--prepare-only 只检查和准备产物，--apk 复用本命令生成的 APK 与 .json 构建记录。'
}
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then usage; exit 0; fi
[[ $# -ge 1 ]] || { usage >&2; exit 1; }
TAG="$1"; shift
PREPARE_ONLY=false
REUSE_APK=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prepare-only) PREPARE_ONLY=true; shift ;;
    --apk) [[ $# -ge 2 ]] || { usage >&2; exit 1; }; REUSE_APK="$2"; shift 2 ;;
    *) usage >&2; exit 1 ;;
  esac
done
[[ "$TAG" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || { echo '版本必须是 vX.Y.Z' >&2; exit 1; }
MAJOR="${BASH_REMATCH[1]}" MINOR="${BASH_REMATCH[2]}" PATCH="${BASH_REMATCH[3]}"
(( MAJOR <= 209999 && MINOR < 100 && PATCH < 100 )) || { echo '版本超出构建号范围' >&2; exit 1; }
BUILD_NUMBER=$((MAJOR * 10000 + MINOR * 100 + PATCH))
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "$REUSE_APK" ]]; then REUSE_APK="$(cd "$(dirname "$REUSE_APK")" && pwd)/$(basename "$REUSE_APK")"; fi
cd "$ROOT"
fail() { echo "$*" >&2; exit 1; }
[[ "$(awk '/^version:/ {print $2}' pubspec.yaml)" == "${TAG#v}+$BUILD_NUMBER" ]] || fail 'pubspec.yaml 版本与 tag 不一致'
[[ -z "$(git status --porcelain)" ]] || fail '请先提交全部源码与版本说明，再发布'
SOURCE_COMMIT="$(git rev-parse HEAD)"
LOCK="$(git rev-parse --git-common-dir)/synlen-release.lock"
mkdir "$LOCK" 2>/dev/null || fail '已有本地发布命令在运行；异常中断后请核对进程再清理 .git/synlen-release.lock'
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"; rmdir "$LOCK"' EXIT
awk -v heading="## $TAG" '$0 == heading {found=1; next} found && /^## / {exit} found {print}' docs/user/release-notes.md > "$WORK/notes.md"
[[ -n "$(tr -d '[:space:]' < "$WORK/notes.md")" ]] || fail "release-notes.md 中缺少 $TAG 说明"
APK_NAME="synlen-${TAG}-arm64-release.apk"
APK="$ROOT/build/outputs/$APK_NAME"
if [[ -n "$REUSE_APK" ]]; then
  APK="$REUSE_APK"
  [[ "$(basename "$APK")" == "$APK_NAME" ]] || fail "安装包文件名必须是 $APK_NAME"
  [[ -f "$APK" && -f "$APK.json" ]] || fail '复用 APK 需要同时保留 .apk 与 .apk.json 构建记录'
  APK_SHA256="$(shasum -a 256 "$APK" | awk '{print $1}')"
  jq -e --arg commit "$SOURCE_COMMIT" --arg sha "$APK_SHA256" '.sourceCommit == $commit and .sha256 == $sha' "$APK.json" >/dev/null || fail 'APK 构建记录与当前提交或文件摘要不一致'
  bash tool/verify_release_apk.sh "$TAG" "$APK"
else
  [[ ! -e "$APK" && ! -e "$APK.json" ]] || fail "已有产物，请用 --apk '$APK' 复用，或保留副本后移走再构建"
  [[ -f android/key.properties ]] || fail '缺少 android/key.properties，不能构建正式签名包'
fi
GH_REPO=Duskriver/Synlen
if [[ "$PREPARE_ONLY" == false ]]; then
  gh auth status --hostname github.com >/dev/null
  if [[ -z "${GITEE_TOKEN:-}" ]]; then GITEE_TOKEN="$(gitee auth token)"; fi
  [[ -n "$GITEE_TOKEN" ]] || fail '未配置 Gitee 发布凭据'
  export GITEE_TOKEN
  # 云端已有 concurrency；本地启动时还需排除正在运行或排队的云发布。
  gh run list --repo "$GH_REPO" --workflow build_release.yml --limit 100 --json databaseId,status > "$WORK/runs.json"
  jq -e --arg self "${GITHUB_RUN_ID:-}" '[.[] | select(.status != "completed" and (.databaseId | tostring) != $self)] | length == 0' "$WORK/runs.json" >/dev/null || fail '云发布正在运行或排队，请结束后再发布'
  git fetch origin main --tags
  if git show-ref --verify --quiet "refs/tags/$TAG"; then
    [[ "$(git rev-parse "$TAG^{commit}")" == "$SOURCE_COMMIT" ]] || fail '已有 tag 指向其他提交，不能替换'
  fi
  BRANCH="$(git branch --show-current)"
  if [[ "$BRANCH" == main ]]; then
    git merge-base --is-ancestor origin/main HEAD || fail 'main 已落后或分叉，请先同步'
  else
    [[ -z "$BRANCH" && "$(git rev-parse "$TAG^{commit}")" == "$SOURCE_COMMIT" ]] || fail '请在 main 或已发布到 main 的 tag 上执行'
    git merge-base --is-ancestor HEAD origin/main || fail 'tag 尚未包含在 origin/main 中'
  fi
fi

echo '执行发布质量门禁'
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
dart run tool/layer_gates.dart
cargo test --locked --manifest-path rust/Cargo.toml
dart run tool/doc_gates.dart
npm ci --prefix web_assets/readium
git diff --exit-code -- web_assets/readium/package-lock.json || fail '阅读器 npm 锁文件发生漂移'
npm run typecheck --prefix web_assets/readium
(
  cd web_assets/readium
  npx playwright install chromium webkit
  npm test
)
dart run tool/build_readium_assets.dart
git diff --exit-code -- assets/reader/readium_learning.js || fail '阅读器学习脚本生成物发生漂移'
[[ -z "$(git status --porcelain)" && "$(git rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail '检查期间源码或提交发生变化，请提交后重新执行'

if [[ -z "$REUSE_APK" ]]; then
  echo '构建 Android ARM64 APK'
  flutter build apk --release --target-platform android-arm64 --build-name="${TAG#v}" --build-number="$BUILD_NUMBER"
  bash tool/verify_release_apk.sh "$TAG" build/app/outputs/flutter-apk/app-release.apk
  [[ -z "$(git status --porcelain)" && "$(git rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail '构建期间源码或提交发生变化，请提交后重新执行'
  mkdir -p build/outputs
  cp build/app/outputs/flutter-apk/app-release.apk "$APK"
  APK_SHA256="$(shasum -a 256 "$APK" | awk '{print $1}')"
  jq -n --arg commit "$SOURCE_COMMIT" --arg sha "$APK_SHA256" '{sourceCommit:$commit,sha256:$sha}' > "$APK.json"
fi
# 新构建与复用产物都须通过原生回归，失败时不得推送标签或上传。
bash tool/test_readium_android.sh || fail 'Readium Android 原生回归未通过'
[[ -z "$(git status --porcelain)" && "$(git rev-parse HEAD)" == "$SOURCE_COMMIT" ]] || fail '原生检查期间源码或提交发生变化，请提交后重新执行'
if [[ "$PREPARE_ONLY" == true ]]; then
  echo "已准备并验证：$APK"
  echo '未推送源码、tag 或发布安装包。'
  exit 0
fi

# 后续重试始终使用这份已验证文件，不重新编译同一构建号。
[[ "$(shasum -a 256 "$APK" | awk '{print $1}')" == "$APK_SHA256" ]] || fail '安装包在检查后发生变化'
if [[ "$BRANCH" == main ]]; then git push origin HEAD:refs/heads/main; fi
if ! git show-ref --verify --quiet "refs/tags/$TAG"; then git tag "$TAG" "$SOURCE_COMMIT"; fi
git push origin "refs/tags/$TAG:refs/tags/$TAG"
bash tool/sync_gitee.sh

echo '发布并验证 GitHub 安装包'
gh api --paginate "repos/$GH_REPO/releases?per_page=100" --jq '.[] | select(.tag_name == "'"$TAG"'")' > "$WORK/release.json"
if [[ ! -s "$WORK/release.json" ]]; then
  gh release create "$TAG" "$APK" --repo "$GH_REPO" --verify-tag --title "$TAG" --notes-file "$WORK/notes.md"
elif ! jq -e --arg name "$APK_NAME" '.assets[]? | select(.name == $name)' "$WORK/release.json" >/dev/null; then
  gh release upload "$TAG" "$APK" --repo "$GH_REPO"
fi
mkdir "$WORK/github"
gh release download "$TAG" --repo "$GH_REPO" --pattern "$APK_NAME" --dir "$WORK/github"
cmp -s "$APK" "$WORK/github/$APK_NAME" || fail 'GitHub 同名 APK 与本地产物不一致，拒绝覆盖或更新清单'
if [[ -s "$WORK/release.json" ]] && jq -e '.draft == true' "$WORK/release.json" >/dev/null; then
  gh release edit "$TAG" --repo "$GH_REPO" --draft=false --title "$TAG" --notes-file "$WORK/notes.md"
fi
# GitHub 附件也就绪后才交给 Gitee 脚本更新客户端清单。
bash tool/upload_release.sh "$TAG" Tang_Lei789/synlen "$APK"
echo "已发布 ${TAG}；保留 $APK 与 $APK.json 供重试。"
