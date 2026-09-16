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
# checkout 必须 fetch-depth: 0，让 origin/main 和所有标签都可见。
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS="$WORK/askpass" \
  git -c credential.helper= push https://gitee.com/Tang_Lei789/synlen.git \
    refs/remotes/origin/main:refs/heads/main 'refs/tags/*:refs/tags/*'
