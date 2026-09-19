#!/usr/bin/env bash
# 检查 APK 中 64 位原生库的 ELF LOAD 段与 ZIP 条目是否满足 16 KB 对齐。
set -euo pipefail
APK="${1:?用法: verify_android_page_alignment.sh <apk路径>}"
[[ -f "$APK" ]] || { echo "未找到 APK: $APK" >&2; exit 1; }
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
ZIPALIGN='' OBJDUMP=''
for candidate in "$SDK"/build-tools/*/zipalign; do
  if [[ -x "$candidate" ]]; then ZIPALIGN="$candidate"; fi
done
for candidate in "$SDK"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-objdump; do
  if [[ -x "$candidate" ]]; then OBJDUMP="$candidate"; fi
done
[[ -n "$SDK" && -n "$ZIPALIGN" && -n "$OBJDUMP" ]] || {
  echo '请设置 ANDROID_HOME 并安装 Android NDK 与 Build-Tools 35+' >&2; exit 1;
}
"$ZIPALIGN" -c -P 16 4 "$APK" || { echo 'APK ZIP 条目未按 16 KB 对齐' >&2; exit 1; }
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
unzip -q "$APK" 'lib/*/*.so' -d "$WORK_DIR"
shopt -s nullglob
COUNT=0 FAILED=0
for library in "$WORK_DIR"/lib/{arm64-v8a,x86_64}/*.so; do
  COUNT=$((COUNT + 1))
  if "$OBJDUMP" -p "$library" | awk '
    /^[[:space:]]*LOAD / {
      count++
      if ($0 !~ /align 2\*\*[0-9]+/) { invalid=1; next }
      sub(/.*align 2\*\*/, "")
      if (($0 + 0) < 14) invalid=1
    }
    END { exit(count == 0 || invalid) }
  '; then
    echo "16 KB 对齐通过：${library#"$WORK_DIR/"}"
  else
    echo "ELF LOAD 段未按 16 KB 对齐：${library#"$WORK_DIR/"}" >&2
    FAILED=1
  fi
done
[[ "$COUNT" -gt 0 ]] || { echo 'APK 未包含可校验的 64 位原生库' >&2; exit 1; }
exit "$FAILED"
