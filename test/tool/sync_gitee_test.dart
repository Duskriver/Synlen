import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory fixture;
  late String source;
  late String github;
  late String mirror;
  final script = File('tool/sync_gitee.sh').absolute.path;

  Future<String> git(String directory, List<String> arguments) async {
    final result = await Process.run(
      'git',
      arguments,
      workingDirectory: directory,
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    return (result.stdout as String).trim();
  }

  Future<ProcessResult> sync() => Process.run(
    'bash',
    [script],
    workingDirectory: source,
    environment: {
      'GITEE_TOKEN': 'fixture-token',
      'GIT_CONFIG_COUNT': '1',
      'GIT_CONFIG_KEY_0': 'url.$mirror.insteadOf',
      'GIT_CONFIG_VALUE_0': 'https://gitee.com/Tang_Lei789/synlen.git',
    },
  );

  setUp(() async {
    fixture = await Directory.systemTemp.createTemp('synlen-sync-test-');
    source = '${fixture.path}/source';
    github = '${fixture.path}/github.git';
    mirror = '${fixture.path}/gitee.git';
    await git(fixture.path, ['init', '--bare', github]);
    await git(fixture.path, ['init', '--bare', mirror]);
    await git(fixture.path, ['init', '-b', 'main', source]);
    await git(source, ['config', 'user.name', 'Test']);
    await git(source, ['config', 'user.email', 'test@example.invalid']);
    await git(source, ['config', 'commit.gpgsign', 'false']);
    await git(source, ['config', 'tag.gpgsign', 'false']);
    await File('$source/book.txt').writeAsString('published');
    await git(source, ['add', 'book.txt']);
    await git(source, ['commit', '-m', 'initial']);
    await git(source, ['remote', 'add', 'origin', github]);
    await git(source, ['push', '-u', 'origin', 'main']);
  });

  tearDown(() => fixture.delete(recursive: true));

  test('只镜像远端 main 和标签，不公开本地实验提交', () async {
    await git(source, ['tag', '-a', 'v1.0.0', '-m', 'published']);
    await git(source, ['push', 'origin', 'refs/tags/v1.0.0']);
    final published = await git(github, ['rev-parse', 'main']);
    await File('$source/book.txt').writeAsString('private experiment');
    await git(source, ['commit', '-am', 'private experiment']);
    await git(source, ['tag', 'local-experiment']);

    final result = await sync();

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await git(mirror, ['tag']), 'v1.0.0');
    expect(await git(mirror, ['rev-parse', 'main']), published);
    expect(
      await git(mirror, ['rev-parse', 'refs/tags/v1.0.0']),
      await git(github, ['rev-parse', 'refs/tags/v1.0.0']),
    );
    expect(await git(source, ['tag']), contains('local-experiment'));
  });

  test('从远端获取本地尚未拉取的标签，不采用本地同名标签', () async {
    final published = await git(github, ['rev-parse', 'main']);
    await git(github, ['update-ref', 'refs/tags/remote-only', published]);
    await File('$source/book.txt').writeAsString('local change');
    await git(source, ['commit', '-am', 'local change']);
    await git(source, ['tag', 'remote-only']);
    final localTag = await git(source, ['rev-parse', 'remote-only']);

    final result = await sync();

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await git(mirror, ['rev-parse', 'remote-only']), published);
    expect(await git(source, ['rev-parse', 'remote-only']), localTag);
  });

  test('远端没有标签时仍可同步 main', () async {
    final result = await sync();
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(await git(mirror, ['tag']), isEmpty);
    expect(
      await git(mirror, ['rev-parse', 'main']),
      await git(github, ['rev-parse', 'main']),
    );
  });
}
