// Synlen 分层门禁。
//
// ignore_for_file: avoid_print —— 这是命令行门禁脚本，stdout 就是它的输出。
//
// 用法：dart run tool/layer_gates.dart [--list]
// 退出码非零表示有违规；CI 与本地提交前都应跑。
//
// 规则来源：docs/architecture.md 的分层与跨 feature 依赖表、
// .agents/notes/implemented/architecture/2026-09-08-composition-surface-cross-feature.md。
import 'dart:io';

const _featuresRoot = 'lib/src/features';
const _corePrefix = 'lib/src/core/';

/// 组合面：唯一允许在 application 层编排其他 feature data 层的模块。
const _compositionSurfaces = <String>{'settings'};

/// feature 内部的分层目录；顺序即依赖方向，前面的层不得依赖后面的层。
const _layers = <String>['presentation', 'application', 'domain', 'data'];

/// 跨 feature 允许依赖的目标层：application 是能力入口，domain 是值类型与纯逻辑。
const _crossFeatureAllowedTargetLayers = <String>{'application', 'domain'};

final List<String> _errors = <String>[];
final List<String> _notes = <String>[];

void main(List<String> args) {
  final repo = Directory.current;
  final files = _collectSources(repo);
  var edges = 0;
  for (final file in files) {
    final importer = _rel(repo, file.path);
    final source = _classify(importer);
    if (source == null) continue;
    for (final target in _targets(repo, file)) {
      edges++;
      _checkEdge(importer, source, target);
    }
  }
  if (args.contains('--list')) {
    _printEdges(repo, files);
  }
  for (final n in _notes) {
    print('· $n');
  }
  if (_errors.isEmpty) {
    print('分层门禁通过：${files.length} 个源文件、$edges 条 import 边，0 个问题。');
    return;
  }
  stderr.writeln('分层门禁失败：${_errors.length} 个问题');
  for (final e in _errors) {
    stderr.writeln('  ✗ $e');
  }
  exitCode = 1;
}

List<File> _collectSources(Directory repo) {
  final out = <File>[];
  for (final f in Directory(
    '${repo.path}/lib/src',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('.g.dart') || f.path.endsWith('.freezed.dart')) {
      continue;
    }
    out.add(f);
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

String _rel(Directory repo, String path) =>
    path.replaceFirst('${repo.path}/', '');

/// 模块与分层：feature 内文件返回 (feature, layer)，core 与外壳返回 (name, '')。
({String module, String layer})? _classify(String rel) {
  final parts = rel.split('/');
  if (parts.length >= 4 && parts[0] == 'lib' && parts[1] == 'src') {
    if (parts[2] == 'features') {
      final feature = parts[3];
      final layer = parts.length >= 5 && _layers.contains(parts[4])
          ? parts[4]
          : '';
      return (module: feature, layer: layer);
    }
    if (parts[2] == 'core') return (module: 'core', layer: '');
  }
  return null;
}

/// 解析 import / export 目标，返回仓库相对路径；无法解析或不在 lib/ 下时跳过。
Iterable<String> _targets(Directory repo, File file) sync* {
  final text = file.readAsStringSync();
  final dir = file.parent.path.replaceFirst('${repo.path}/', '');
  for (final m in RegExp(
    r"^\s*(?:import|export)\s+'([^']+)'",
    multiLine: true,
  ).allMatches(text)) {
    final raw = m.group(1)!;
    String resolved;
    if (raw.startsWith('package:synlen/')) {
      resolved = 'lib/${raw.substring('package:synlen/'.length)}';
    } else if (raw.startsWith('.')) {
      resolved = _normalize('$dir/$raw');
    } else {
      continue;
    }
    if (!resolved.endsWith('.dart')) resolved = '$resolved.dart';
    if (!File('${repo.path}/$resolved').existsSync()) continue;
    yield resolved;
  }
}

String _normalize(String path) {
  final parts = <String>[];
  for (final seg in path.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return parts.join('/');
}

void _checkEdge(
  String importer,
  ({String module, String layer}) source,
  String target,
) {
  final dep = _classify(target);
  if (dep == null) return;
  final label = '$importer -> $target';

  // 规则 1：presentation 不得依赖 data（本 feature 与跨 feature 一致）。
  if (source.layer == 'presentation' && dep.layer == 'data') {
    _errors.add('presentation 不得依赖 data：$label');
    return;
  }

  // 规则 2：domain 是纯逻辑层，不得依赖上层。
  if (source.layer == 'domain' &&
      const {'application', 'presentation', 'data'}.contains(dep.layer)) {
    _errors.add('domain 不得依赖 ${dep.layer}：$label');
    return;
  }

  // 规则 3：跨 feature 只允许 application / domain 目标；data 仅限组合面 application 编排。
  final importerIsFeature = importer.startsWith('$_featuresRoot/');
  final targetIsFeature = target.startsWith('$_featuresRoot/');
  if (importerIsFeature && targetIsFeature && source.module != dep.module) {
    final allowed =
        _crossFeatureAllowedTargetLayers.contains(dep.layer) ||
        (_compositionSurfaces.contains(source.module) &&
            source.layer == 'application' &&
            dep.layer == 'data');
    if (!allowed) {
      _errors.add(
        '跨 feature 依赖形态不合法（${source.module}/${source.layer} -> '
        '${dep.module}/${dep.layer}）：$label',
      );
      return;
    }
  }

  // 规则 4：core 是共享工具箱，只能依赖 feature 的 domain 值类型。
  if (importer.startsWith(_corePrefix) &&
      dep.module != 'core' &&
      dep.layer != 'domain') {
    _errors.add('core 不得依赖 feature 的 ${dep.layer}：$label');
  }
}

void _printEdges(Directory repo, List<File> files) {
  final cross = <String>{};
  final coreToFeature = <String>{};
  for (final file in files) {
    final importer = _rel(repo, file.path);
    final source = _classify(importer);
    if (source == null) continue;
    for (final target in _targets(repo, file)) {
      final dep = _classify(target);
      if (dep == null) continue;
      final targetIsFeature = target.startsWith('$_featuresRoot/');
      final importerIsFeature = importer.startsWith('$_featuresRoot/');
      if (!targetIsFeature) continue;
      if (importerIsFeature && source.module != dep.module) {
        cross.add(
          '${source.module}/${source.layer} -> ${dep.module}/${dep.layer}  ($importer)',
        );
      } else if (importer.startsWith(_corePrefix)) {
        coreToFeature.add(
          '${source.module}/${source.layer} -> ${dep.module}/${dep.layer}  ($importer)',
        );
      }
    }
  }
  print('-- 跨 feature 边 --');
  for (final e in cross.toList()..sort()) {
    print('  $e');
  }
  print('-- core -> feature 边 --');
  for (final e in coreToFeature.toList()..sort()) {
    print('  $e');
  }
}
