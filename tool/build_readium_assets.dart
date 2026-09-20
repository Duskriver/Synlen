// 独立构建学习脚本；Readium 负责排版，不依赖 Flutter 或旧分页资源。
// ignore_for_file: avoid_print
import 'dart:io';

Future<void> main() async {
  final executable = File(
    'web_assets/readium/node_modules/.bin/esbuild${Platform.isWindows ? '.cmd' : ''}',
  ).absolute.path;
  final result = await Process.run(executable, [
    'web_assets/readium/index.ts',
    '--bundle',
    '--minify',
    '--format=iife',
    '--target=es2015,chrome80,safari15,ios15',
  ], runInShell: Platform.isWindows);
  if (result.exitCode != 0) {
    stderr.write(result.stderr);
    exitCode = result.exitCode;
    return;
  }
  final output = File('assets/reader/readium_learning.js');
  await output.parent.create(recursive: true);
  await output.writeAsString(
    '// 自动生成；运行 dart run tool/build_readium_assets.dart 更新。\n'
    '${(result.stdout as String).trim()}\n',
  );
  print('Readium 学习脚本已生成：${output.path}');
}
