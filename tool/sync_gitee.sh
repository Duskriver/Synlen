#!/usr/bin/env bash
# GitHub 为唯一写入源；Gitee 同步 main 与标签，updates 分支由发布脚本维护。
set -euo pipefail
: "${GITEE_TOKEN:?需要 GITEE_TOKEN}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/askpass" <<'ASKPASS'
#!/usr/bin/env bash
case "$1" in
  *Username*) printf '%s\n' 'Tang_Lei789' ;;
  *Password*) printf '%s\n' "$GITEE_TOKEN" ;;
esac
ASKPASS
chmod 700 "$WORK/askpass"
# 从远端独立取引用，避免开发工作区的未发布标签进入公开镜像。
SOURCE_URL="$(git remote get-url origin)"
git init --quiet --bare "$WORK/source.git"
GIT_TERMINAL_PROMPT=0 git -C "$WORK/source.git" fetch --quiet --no-tags "$SOURCE_URL" \
  'refs/heads/main:refs/heads/main' 'refs/tags/*:refs/tags/*'
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS="$WORK/askpass" \
  git -C "$WORK/source.git" -c credential.helper= push https://gitee.com/Tang_Lei789/synlen.git \
    refs/heads/main:refs/heads/main 'refs/tags/*:refs/tags/*'
