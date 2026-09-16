import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixture;
  late Map<String, String> environment;

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('synlen-publish-test-');
    for (final path in ['tool', 'bin', 'docs/user']) {
      await Directory('${fixture.path}/$path').create(recursive: true);
    }
    await File(
      'tool/upload_release.sh',
    ).copy('${fixture.path}/tool/upload_release.sh');
    await File(
      '${fixture.path}/docs/user/release-notes.md',
    ).writeAsString('## v0.3.0\n\n更新说明\n\n## v0.2.0\n旧说明\n');
    await File('${fixture.path}/app.apk').writeAsString('test APK bytes');
    await File('${fixture.path}/bin/curl').writeAsString(r'''#!/usr/bin/env bash
set -euo pipefail
url='' out='' method=GET data='' status=false auth=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) auth=true; shift 2 ;;
    -o) out="$2"; shift 2 ;;
    -w) status=true; shift 2 ;;
    -X) method="$2"; shift 2 ;;
    --data-binary) data="${2#@}"; shift 2 ;;
    -H|-F|--connect-timeout|--max-time|--proto|--proto-redir) shift 2 ;;
    https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s %s\n' "$method" "$url" >> "$FIXTURE/requests"
code=200
case "$url" in
  */test/releases) response='{"public":true,"default_branch":"master"}' ;;
  */contents/version.json*)
    if [[ "$method" == GET ]]; then
      if [[ -f "$FIXTURE/published.json" ]]; then
        content="$(base64 < "$FIXTURE/published.json" | tr -d '\n')"
        response="$(jq -n --arg c "$content" '{content:$c,sha:"previous"}')"
      elif [[ "${SCENARIO:-}" == downgrade ]]; then
        content="$(printf '{"code":200,"data":{"buildNumber":400}}' | base64 | tr -d '\n')"
        response="$(jq -n --arg c "$content" '{content:$c,sha:"previous"}')"
      else
        response='[]'
      fi
    else
      if [[ "$method" == PUT ]]; then jq -e '.sha == "previous"' "$data" >/dev/null; fi
      jq -r '.content' "$data" | base64 --decode > "$FIXTURE/published.json"
      response='{}'
    fi ;;
  */releases/tags/v0.3.0)
    if [[ "${SCENARIO:-}" == retry ]]; then
      response='{"id":1,"assets":[{"name":"app.apk","browser_download_url":"https://gitee.com/test/release.apk"}]}'
    else
      code=404; response='{}'
    fi ;;
  */releases) response='{"id":1,"assets":[]}' ;;
  */attach_files) response='{"browser_download_url":"https://gitee.com/test/release.apk"}' ;;
  */release.apk)
    [[ "$auth" == false ]] || exit 90
    if [[ "${SCENARIO:-}" == mismatch ]]; then
      printf 'corrupt bytes' > "$out"
    else
      cp "$FIXTURE/app.apk" "$out"
    fi
    exit 0 ;;
  */raw/updates/version.json)
    [[ "$auth" == false ]] || exit 91
    cp "$FIXTURE/published.json" "$out"; exit 0 ;;
  *) echo "unexpected URL: $url" >&2; exit 92 ;;
esac
if [[ -n "$out" ]]; then printf '%s' "$response" > "$out"; else printf '%s' "$response"; fi
if [[ "$status" == true ]]; then printf '%s' "$code"; fi
''');
    await Process.run('chmod', ['+x', '${fixture.path}/bin/curl']);
    environment = {
      'PATH': '${fixture.path}/bin:${Platform.environment['PATH']}',
      'GITEE_TOKEN': 'test-token',
      'FIXTURE': fixture.path,
    };
  });

  tearDown(() => fixture.delete(recursive: true));

  Future<ProcessResult> publish({String tag = 'v0.3.0'}) => Process.run(
    'bash',
    ['tool/upload_release.sh', tag, 'test/releases', '${fixture.path}/app.apk'],
    workingDirectory: fixture.path,
    environment: environment,
  );

  test('匿名校验完成后发布兼容客户端的清单', () async {
    final result = await publish();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final manifest = await File(
      '${fixture.path}/build/outputs/version.json',
    ).readAsString();
    expect(manifest, contains('"buildNumber": 300'));
    expect(manifest, contains('更新说明'));
    expect(manifest, isNot(contains('旧说明')));
    final requests = await File('${fixture.path}/requests').readAsString();
    expect(
      requests.indexOf('GET https://gitee.com/test/release.apk'),
      lessThan(
        requests.indexOf(
          'POST https://gitee.com/api/v5/repos/test/releases/contents/version.json',
        ),
      ),
    );
  });

  test('重试复用附件并携带文件 SHA 更新清单', () async {
    expect((await publish()).exitCode, 0);
    environment['SCENARIO'] = 'retry';
    await File('${fixture.path}/requests').writeAsString('');
    final result = await publish();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final requests = await File('${fixture.path}/requests').readAsString();
    expect(requests, isNot(contains('/attach_files')));
    expect(
      requests,
      contains(
        'PUT https://gitee.com/api/v5/repos/test/releases/contents/version.json',
      ),
    );
  });

  test('下载摘要不匹配时不更新清单', () async {
    environment['SCENARIO'] = 'mismatch';
    final result = await publish();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('摘要不匹配'));
    expect(File('${fixture.path}/published.json').existsSync(), isFalse);
  });

  test('拒绝向已发布的新版本回退', () async {
    environment['SCENARIO'] = 'downgrade';
    final result = await publish();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('拒绝降级'));
    expect(File('${fixture.path}/published.json').existsSync(), isFalse);
  });

  test('非法版本号在请求网络前失败', () async {
    final result = await publish(tag: 'v0.3.0;echo bad');
    expect(result.exitCode, isNot(0));
    expect(File('${fixture.path}/requests').existsSync(), isFalse);
  });
}
