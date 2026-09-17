import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixture;
  late Directory repo;
  late Map<String, String> environment;
  const tag = 'v0.3.4';
  const apkName = 'synlen-v0.3.4-arm64-release.apk';

  Future<ProcessResult> git(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: repo.path);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return result;
  }

  Future<void> executable(String path, String contents) async {
    final file = File('${fixture.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '#!/usr/bin/env bash\nset -euo pipefail\n$contents',
    );
    await Process.run('chmod', ['+x', file.path]);
  }

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('synlen-local-release-');
    repo = await Directory('${fixture.path}/repo').create();
    for (final path in [
      'tool',
      'docs/user',
      'android',
      'web_assets/controller.js',
    ]) {
      await Directory('${repo.path}/$path').create(recursive: true);
    }
    for (final script in ['release.sh', 'verify_release_apk.sh']) {
      await File('tool/$script').copy('${repo.path}/tool/$script');
    }
    await File(
      '${repo.path}/pubspec.yaml',
    ).writeAsString('version: 0.3.4+304\n');
    await File('${repo.path}/.gitignore').writeAsString('build/\n');
    await File(
      '${repo.path}/android/key.properties',
    ).writeAsString('fixture\n');
    await File(
      '${repo.path}/docs/user/release-notes.md',
    ).writeAsString('## v0.3.4\n\n本版本的更新说明\n\n## v0.3.3\n\n旧版本说明\n');
    // 网络分发留在现有脚本的测试中，这里只记录其调用与失败时序。
    await executable(
      'repo/tool/sync_gitee.sh',
      r'echo sync-gitee >> "$FIXTURE/events"',
    );
    await executable('repo/tool/upload_release.sh', r'''
echo upload-gitee >> "$FIXTURE/events"
[[ "${SCENARIO:-}" != gitee-failure ]] || exit 70
cp "$3" "$FIXTURE/gitee.apk"
''');
    for (final command in ['flutter', 'dart', 'cargo', 'npm', 'npx']) {
      await executable('bin/$command', r'''
command="$(basename "$0")"
echo "$command $*" >> "$FIXTURE/events"
if [[ "$command $1" == 'flutter test' && "${SCENARIO:-}" == test-failure ]]; then exit 20; fi
if [[ "$command $1" == 'flutter build' ]]; then
  mkdir -p build/app/outputs/flutter-apk
  printf 'APK bytes from the build' > build/app/outputs/flutter-apk/app-release.apk
fi
if [[ "$command $*" == 'dart run tool/build_web_assets.dart' && "${SCENARIO:-}" == drift ]]; then
  printf '\nchanged\n' >> pubspec.yaml
fi
''');
    }
    await executable('sdk/build-tools/36.0.0/aapt', r'''
version=0.3.4
[[ "${SCENARIO:-}" != wrong-version ]] || version=0.3.3
echo "package: name='com.tanglei.synlen' versionCode='304' versionName='$version'"
''');
    await executable('sdk/build-tools/36.0.0/apksigner', r'''
[[ "${SCENARIO:-}" != invalid-signature ]] || exit 1
fingerprint=aaecfc6b98149129dfb674117b663af6cd524e34b3dd7af8ad0a3c87bc3d21ff
[[ "${SCENARIO:-}" != debug-signature ]] || fingerprint=wrong
echo "Signer #1 certificate SHA-256 digest: $fingerprint"
''');
    await executable('bin/unzip', r'''
echo lib/arm64-v8a/libapp.so
if [[ "${SCENARIO:-}" == wrong-abi ]]; then echo lib/x86_64/libapp.so; fi
''');
    await executable('bin/gh', r'''
echo "gh $1 ${2:-}" >> "$FIXTURE/events"
asset="$FIXTURE/github.apk"
case "$1 ${2:-}" in
  'auth status') ;;
  'run list')
    if [[ "${SCENARIO:-}" == busy || "${SCENARIO:-}" == self ]]; then
      echo '[{"databaseId":7,"status":"in_progress"}]'
    else echo '[]'; fi ;;
  'api --paginate')
    if [[ -f "$asset" ]]; then
      echo '{"draft":false,"assets":[{"name":"synlen-v0.3.4-arm64-release.apk"}]}'
    fi ;;
  'release create'|'release upload')
    [[ ! -f "$asset" ]] || exit 91
    cp "$4" "$asset" ;;
  'release download')
    directory='' pattern=''
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dir) directory="$2"; shift 2 ;;
        --pattern) pattern="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cp "$asset" "$directory/$pattern" ;;
  *) echo "unexpected gh command: $*" >&2; exit 92 ;;
esac
''');
    environment = {
      'PATH': '${fixture.path}/bin:${Platform.environment['PATH']}',
      'FIXTURE': fixture.path,
      'ANDROID_HOME': '${fixture.path}/sdk',
      'GITEE_TOKEN': 'fixture-token',
      'GITHUB_RUN_ID': '',
    };
    await git(['init', '-b', 'main']);
    await git(['config', 'user.name', 'Release Test']);
    await git(['config', 'user.email', 'release-test@example.invalid']);
    await git(['config', 'commit.gpgsign', 'false']);
    await git(['add', '.']);
    await git(['commit', '-m', 'fixture']);
    await git(['init', '--bare', '${fixture.path}/origin.git']);
    await git(['remote', 'add', 'origin', '${fixture.path}/origin.git']);
    await git(['push', '-u', 'origin', 'main']);
  });

  tearDown(() => fixture.delete(recursive: true));

  Future<ProcessResult> release([List<String> options = const []]) =>
      Process.run(
        'bash',
        ['tool/release.sh', tag, ...options],
        workingDirectory: repo.path,
        environment: environment,
      );

  String events() {
    final file = File('${fixture.path}/events');
    return file.existsSync() ? file.readAsStringSync() : '';
  }

  Future<void> expectSuccess(ProcessResult result) async {
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }

  Future<void> expectUnpublished() async {
    final refs = await git(['ls-remote', '--tags', 'origin']);
    expect(refs.stdout, isEmpty);
    expect(File('${fixture.path}/github.apk').existsSync(), isFalse);
    expect(File('${fixture.path}/gitee.apk').existsSync(), isFalse);
  }

  test('演练检查构建并记录源码摘要，不创建远端发布', () async {
    await expectSuccess(await release(['--prepare-only']));
    final record =
        jsonDecode(
              await File(
                '${repo.path}/build/outputs/$apkName.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    expect(
      record['sourceCommit'],
      (await git(['rev-parse', 'HEAD'])).stdout.toString().trim(),
    );
    expect(record['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(events(), isNot(contains('gh ')));
    await expectUnpublished();
  });

  test('门禁与构建后同步标签，两边发布同一文件，重试不重建或覆盖', () async {
    await expectSuccess(await release());
    final calls = events();
    expect(
      calls.indexOf('flutter test'),
      lessThan(calls.indexOf('flutter build')),
    );
    expect(calls.indexOf('npm test'), lessThan(calls.indexOf('flutter build')));
    expect(
      calls.indexOf('flutter build'),
      lessThan(calls.indexOf('sync-gitee')),
    );
    expect(
      calls.indexOf('gh release download'),
      lessThan(calls.indexOf('upload-gitee')),
    );
    final head = (await git(['rev-parse', 'HEAD'])).stdout.toString().trim();
    expect(
      (await git(['ls-remote', '--tags', 'origin'])).stdout,
      contains('$head\trefs/tags/$tag'),
    );
    expect(
      await File('${fixture.path}/github.apk').readAsBytes(),
      await File('${fixture.path}/gitee.apk').readAsBytes(),
    );
    await File('${fixture.path}/events').writeAsString('');
    await expectSuccess(await release(['--apk', 'build/outputs/$apkName']));
    expect(events(), isNot(contains('flutter build')));
    expect(events(), isNot(contains('gh release create')));
    expect(events(), isNot(contains('gh release upload')));
  });

  for (final scenario in [
    'test-failure',
    'drift',
    'wrong-version',
    'debug-signature',
    'invalid-signature',
    'wrong-abi',
    'busy',
  ]) {
    test('$scenario 阻止推送标签与上传', () async {
      environment['SCENARIO'] = scenario;
      final result = await release();
      expect(
        result.exitCode,
        isNot(0),
        reason: '${result.stdout}\n${result.stderr}',
      );
      final expectedErrors = {
        'drift': '检查期间源码或提交发生变化',
        'wrong-version': 'APK 包名、版本号或构建号',
        'debug-signature': 'APK 签名与正式发布证书不一致',
        'wrong-abi': 'APK 必须只包含 ARM64',
        'busy': '云发布正在运行或排队',
      };
      if (expectedErrors.containsKey(scenario)) {
        expect(result.stderr, contains(expectedErrors[scenario]));
      }
      if (scenario == 'test-failure') {
        expect(events(), contains('flutter test'));
        expect(events(), isNot(contains('flutter build')));
      }
      if (scenario == 'invalid-signature') {
        expect(events(), contains('flutter build'));
      }
      await expectUnpublished();
    });
  }

  test('未提交源码在执行检查前被拒绝', () async {
    await File(
      '${repo.path}/pubspec.yaml',
    ).writeAsString('version: 0.3.4+304\n# dirty\n');
    final result = await release();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('请先提交'));
    expect(events(), isEmpty);
    await expectUnpublished();
  });

  test('已有 tag 指向其他提交时拒绝复用版本', () async {
    await git(['tag', tag]);
    await File('${repo.path}/source.txt').writeAsString('new source');
    await git(['add', '.']);
    await git(['commit', '-m', 'new source']);
    final result = await release();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('已有 tag 指向其他提交'));
    await expectUnpublished();
  });

  for (final changeSource in [false, true]) {
    test('复用产物拒绝${changeSource ? '源码提交' : 'APK 字节'}变化', () async {
      await expectSuccess(await release(['--prepare-only']));
      if (changeSource) {
        await File('${repo.path}/source.txt').writeAsString('new source');
        await git(['add', '.']);
        await git(['commit', '-m', 'new source']);
      } else {
        await File(
          '${repo.path}/build/outputs/$apkName',
        ).writeAsString('changed bytes');
      }
      final result = await release(['--apk', 'build/outputs/$apkName']);
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('构建记录与当前提交或文件摘要不一致'));
      await expectUnpublished();
    });
  }

  test('GitHub 同名附件不一致时保留原文件且不更新 Gitee', () async {
    await File('${fixture.path}/github.apk').writeAsString('previous bytes');
    final result = await release();
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('GitHub 同名 APK'));
    expect(
      await File('${fixture.path}/github.apk').readAsString(),
      'previous bytes',
    );
    expect(File('${fixture.path}/gitee.apk').existsSync(), isFalse);
  });

  test('Gitee 失败后可以复用原 APK 继续发布', () async {
    environment['SCENARIO'] = 'gitee-failure';
    expect((await release()).exitCode, isNot(0));
    final original = await File('${fixture.path}/github.apk').readAsBytes();
    environment.remove('SCENARIO');
    await File('${fixture.path}/events').writeAsString('');
    await expectSuccess(await release(['--apk', 'build/outputs/$apkName']));
    expect(await File('${fixture.path}/gitee.apk').readAsBytes(), original);
    expect(events(), isNot(contains('flutter build')));
    expect(events(), isNot(contains('gh release upload')));
  });

  test('手动云发布支持检出 tag，当前运行不会阻止自身', () async {
    await git(['tag', tag]);
    await git(['push', 'origin', tag]);
    await git(['checkout', '--detach', tag]);
    environment['SCENARIO'] = 'self';
    environment['GITHUB_RUN_ID'] = '7';
    await expectSuccess(await release());
    expect(File('${fixture.path}/gitee.apk').existsSync(), isTrue);
  });
}
