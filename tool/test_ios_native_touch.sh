#!/usr/bin/env bash
# UIKit 视口需 XCTest 原生输入；Flutter 测试只协调目标并验证应用状态。
set -uo pipefail

device="${1:?用法：bash tool/test_ios_native_touch.sh <simulator-id> [integration-test] [日志目录]}"
target="${2:-integration_test/word_popover_smoke_test.dart}"
logs="${3:-$(mktemp -d "${TMPDIR:-/tmp}/synlen-ios-touch.XXXXXX")}"
root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$logs"
logs="$(cd "$logs" && pwd)"
cd "$root" || exit 1

if curl --silent --fail --max-time 1 http://127.0.0.1:8766/state >/dev/null; then
  echo "端口 8766 已有测试；请等该测试结束。" >&2
  exit 1
fi

if ! xcodebuild build-for-testing \
  -project integration_test/native_touch/Probe.xcodeproj \
  -scheme ProbeUITests -destination "id=$device" \
  -derivedDataPath "$logs/driver" -quiet >"$logs/driver-build.log" 2>&1; then
  cat "$logs/driver-build.log"
  exit 1
fi

flutter test --no-pub "$target" -d "$device" \
  --dart-define=SYNLEN_NATIVE_GESTURE_PROBE=true "${@:4}" >"$logs/flutter.log" 2>&1 &
flutter_pid=$!
trap 'if [[ -n "${flutter_pid:-}" ]]; then kill -INT "$flutter_pid" 2>/dev/null || true; fi' EXIT

ready=false
for ((attempt = 0; attempt < 600; attempt++)); do
  if curl --silent --fail --max-time 1 http://127.0.0.1:8766/state >/dev/null; then
    ready=true
    break
  fi
  kill -0 "$flutter_pid" 2>/dev/null || break
  sleep 0.5
done
if [[ "$ready" != true ]]; then
  cat "$logs/flutter.log"
  echo "原生输入协调器未就绪；日志：$logs" >&2
  exit 1
fi

xctestrun="$(find "$logs/driver/Build/Products" -maxdepth 1 -name '*.xctestrun' -print -quit)"
xcodebuild test-without-building -xctestrun "$xctestrun" \
  -destination "id=$device" -collect-test-diagnostics never \
  -resultBundlePath "$logs/native.xcresult" \
  >"$logs/native.log" 2>&1
native_status=$?
if [[ "$native_status" != 0 ]]; then
  cat "$logs/native.log"
  exit "$native_status"
fi
wait "$flutter_pid"
flutter_status=$?
flutter_pid=
cat "$logs/flutter.log"
echo "原生输入与 Flutter 验收日志：$logs"
exit "$flutter_status"
