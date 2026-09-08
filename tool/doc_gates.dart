// Synlen 文档门禁。
//
// ignore_for_file: avoid_print —— 这是命令行门禁脚本，stdout 就是它的输出。
//
// 用法：dart run tool/doc_gates.dart [--list]
// 退出码非零表示有检查失败；CI 与本地提交前都应跑。
import 'dart:convert';
import 'dart:io';

const _docRoots = <String>[
  'AGENTS.md',
  'README.md',
  'docs',
  '.agents/notes',
  '.agents/skills',
];

const _skipDirs = <String>[
  '.agents/notes/archived',
  'node_modules',
  'build',
  '.dart_tool',
];
const _noteLifecycles = <String>['proposed', 'implemented', 'rejected'];
const _noteClasses = <String>[
  'feature',
  'bug-fix',
  'simplification',
  'architecture',
  'process',
  'testing',
];
const _budgetFile = 'tool/doc-budgets.json';

final List<String> _errors = <String>[];
final List<String> _notes = <String>[];

void main(List<String> args) {
  final repo = Directory.current;
  final files = _collectMarkdown(repo);
  _verifyLinks(repo, files);
  _verifyRepoPaths(repo, files);
  _verifyHygiene(files);
  _verifyGlossary(repo);
  _verifyBannedAliases(repo);
  _verifyAgentNotes(repo);
  _verifySkills(repo);
  _verifyBudgets(repo);
  _verifyDevNotes(files);
  if (args.contains('--list')) {
    for (final f in files) {
      print('${f.path}  ${_lineCount(f)} 行');
    }
  }
  for (final n in _notes) {
    print('· $n');
  }
  if (_errors.isEmpty) {
    print('文档门禁通过：${files.length} 份文档，0 个问题。');
    return;
  }
  stderr.writeln('文档门禁失败：${_errors.length} 个问题');
  for (final e in _errors) {
    stderr.writeln('  ✗ $e');
  }
  exitCode = 1;
}

List<File> _collectMarkdown(Directory repo) {
  final out = <File>[];
  for (final root in _docRoots) {
    final entity = FileSystemEntity.typeSync('${repo.path}/$root');
    if (entity == FileSystemEntityType.file) {
      out.add(File('${repo.path}/$root'));
    } else if (entity == FileSystemEntityType.directory) {
      for (final f in Directory(
        '${repo.path}/$root',
      ).listSync(recursive: true).whereType<File>()) {
        final rel = _rel(repo, f.path);
        if (!rel.endsWith('.md')) continue;
        if (_skipDirs.any((d) => rel.startsWith(d))) continue;
        out.add(f);
      }
    }
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

String _rel(Directory repo, String path) =>
    path.replaceFirst('${repo.path}/', '');

int _lineCount(File f) => f.readAsLinesSync().length;

String _display(File f) =>
    f.path.replaceFirst('${Directory.current.path}/', '');

// ---------- 链接 ----------

void _verifyLinks(Directory repo, List<File> files) {
  final anchorCache = <String, Set<String>>{};
  for (final f in files) {
    final rel = _rel(repo, f.path);
    final text = f.readAsStringSync();
    for (final m in RegExp(r'\[[^\]]*\]\(([^)]+)\)').allMatches(text)) {
      var target = m.group(1)!.trim();
      if (target.startsWith('<') && target.endsWith('>')) {
        target = target.substring(1, target.length - 1);
      }
      if (target.isEmpty) {
        continue;
      }
      if (RegExp(
        r'^[a-z][a-z0-9+.-]*:',
        caseSensitive: false,
      ).hasMatch(target)) {
        continue;
      }
      final hash = target.indexOf('#');
      final pathPart = hash == -1 ? target : target.substring(0, hash);
      final fragment = hash == -1 ? '' : target.substring(hash + 1);
      final baseDir = f.parent.path;
      final resolved = pathPart.isEmpty
          ? f.path
          : _normalize('$baseDir/$pathPart');
      final type = FileSystemEntity.typeSync(resolved);
      if (type == FileSystemEntityType.notFound) {
        _errors.add('$rel: 链接目标不存在 -> $target');
        continue;
      }
      if (fragment.isEmpty) continue;
      final targetFile = type == FileSystemEntityType.directory
          ? File('$resolved/README.md')
          : File(resolved);
      if (!targetFile.existsSync()) {
        _errors.add('$rel: 锚点目标无法解析 -> $target');
        continue;
      }
      final anchors = anchorCache.putIfAbsent(
        targetFile.path,
        () => _anchors(targetFile),
      );
      if (!anchors.contains(fragment)) {
        _errors.add('$rel: 锚点不存在 -> $target');
      }
    }
  }
}

String _normalize(String path) {
  final absolute = path.startsWith('/');
  final parts = <String>[];
  for (final seg in path.split('/')) {
    if (seg == '.' || seg.isEmpty) continue;
    if (seg == '..') {
      if (parts.isNotEmpty) parts.removeLast();
      continue;
    }
    parts.add(seg);
  }
  return (absolute ? '/' : '') + parts.join('/');
}

Set<String> _anchors(File f) {
  final out = <String>{};
  var inFence = false;
  for (final line in f.readAsLinesSync()) {
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    for (final m in RegExp(r'<a\s+(?:id|name)="([^"]+)"').allMatches(line)) {
      out.add(m.group(1)!);
    }
    final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (h != null) out.add(_slug(h.group(2)!));
  }
  return out;
}

String _slug(String heading) {
  var s = heading.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
  s = s.replaceAll(RegExp(r'[`*_]'), '');
  s = s.replaceAll(RegExp(r'[^\p{L}\p{N} \-]', unicode: true), '');
  s = s.replaceAll(RegExp(r'\s+'), '-');
  return s;
}

// ---------- 文档里引用的仓库路径 ----------

const _repoPathPrefixes = <String>[
  'lib/',
  'test/',
  'tool/',
  'web_assets/',
  'docs/',
  '.agents/',
  'assets/',
  'rust/',
  'android/',
  'ios/',
  'scripts/',
];

/// 生成或依赖目录：只在装好工具链后存在，干净检出里不该被要求存在。
const _generatedPathSegments = <String>['node_modules', 'build', '.dart_tool'];

void _verifyRepoPaths(Directory repo, List<File> files) {
  for (final f in files) {
    final rel = _rel(repo, f.path);
    if (rel.startsWith('.agents/notes/')) continue;
    final text = f.readAsStringSync();
    for (final m in RegExp(r'`([^`\n]+)`').allMatches(text)) {
      final token = m.group(1)!.trim();
      if (token.contains('<') || token.contains('*') || token.contains('{')) {
        continue;
      }
      if (!_repoPathPrefixes.any(token.startsWith)) continue;
      if (!token.contains('/')) continue;
      if (RegExp(
        r'^[a-z][a-z0-9+.-]*:',
        caseSensitive: false,
      ).hasMatch(token)) {
        continue;
      }
      if (token.split('/').any(_generatedPathSegments.contains)) continue;
      if (FileSystemEntity.typeSync('${repo.path}/$token') ==
          FileSystemEntityType.notFound) {
        _errors.add('$rel: 引用的仓库路径不存在 -> $token');
      }
    }
  }
}

// ---------- Markdown 卫生 ----------

void _verifyHygiene(List<File> files) {
  for (final f in files) {
    final text = f.readAsStringSync();
    final rel = _display(f);
    if (!text.endsWith('\n')) {
      _errors.add('$rel: 文件末尾缺少换行');
    } else if (text.endsWith('\n\n')) {
      _errors.add('$rel: 文件末尾有多余空行');
    }
    final lines = text.split('\n');
    // YAML frontmatter（技能文件）不参与段落与标题检查。
    var frontmatterEnd = -1;
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          frontmatterEnd = i;
          break;
        }
      }
    }
    var inFence = false;
    var h1 = 0;
    var plainRun = 0;
    for (var i = 0; i < lines.length; i++) {
      if (i <= frontmatterEnd) continue;
      final line = lines[i];
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        plainRun = 0;
        continue;
      }
      if (inFence) continue;
      if (line.endsWith(' ') || line.endsWith('\t')) {
        _errors.add('$rel:${i + 1}: 行尾有多余空白');
      }
      if (RegExp(r'^# ').hasMatch(line)) h1++;
      final isPlain =
          line.trim().isNotEmpty &&
          !RegExp(
            r'^(#{1,6}\s|[-*+]\s|\d+[.)]\s|\||>|\s|<!--|<[a-zA-Z/]|\[|!)',
          ).hasMatch(line) &&
          !line.trim().startsWith('|');
      if (isPlain) {
        plainRun++;
        if (plainRun == 2) {
          _errors.add('$rel:${i + 1}: 段落被硬折行（一物理行一段落）');
        }
      } else {
        plainRun = 0;
      }
    }
    if (h1 == 0) _errors.add('$rel: 缺少一级标题');
    if (h1 > 1) _errors.add('$rel: 有 $h1 个一级标题，只能有一个');
  }
}

// ---------- 术语与代码一致 ----------

void _verifyGlossary(Directory repo) {
  final file = File('${repo.path}/docs/glossary.md');
  if (!file.existsSync()) {
    _errors.add('docs/glossary.md: 缺失');
    return;
  }
  final sources = <String>[];
  for (final dir in ['lib']) {
    for (final f in Directory(
      '${repo.path}/$dir',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      sources.add(f.readAsStringSync());
    }
  }
  final haystack = sources.join('\n');
  var checked = 0;
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    if (!t.startsWith('|')) continue;
    final cells = t.split('|');
    if (cells.length < 2) continue;
    final first = cells[1];
    for (final m in RegExp(r'`([A-Za-z][A-Za-z0-9_]*)`').allMatches(first)) {
      final name = m.group(1)!;
      checked++;
      final decl = RegExp(
        r'\b(class|enum|typedef|mixin|extension)\s+' +
            RegExp.escape(name) +
            r'\b',
      );
      if (!decl.hasMatch(haystack)) {
        _errors.add('docs/glossary.md: 术语 $name 在 lib/ 里没有对应声明');
      }
    }
  }
  _notes.add('术语核对：$checked 个标识符');
}

// ---------- Agent Notes ----------

void _verifyAgentNotes(Directory repo) {
  final root = Directory('${repo.path}/.agents/notes');
  if (!root.existsSync()) return;
  var count = 0;
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    final rel = _rel(repo, f.path);
    if (!rel.endsWith('.md')) continue;
    if (rel.endsWith('README.md') || rel.endsWith('AGENTS.md')) continue;
    final parts = rel.split('/');
    if (parts.length < 5) {
      _errors.add(
        '$rel: 路径必须是 .agents/notes/{lifecycle}/{class}/yyyy-mm-dd-slug.md',
      );
      continue;
    }
    final lifecycle = parts[2];
    final klass = parts[3];
    final name = parts[4];
    if (lifecycle == 'archived') continue;
    count++;
    if (!_noteLifecycles.contains(lifecycle)) {
      _errors.add('$rel: 未知生命周期 $lifecycle');
    }
    if (!_noteClasses.contains(klass)) {
      _errors.add('$rel: 未知类别 $klass');
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}-[a-z0-9-]+\.md$').hasMatch(name)) {
      _errors.add('$rel: 文件名必须是 yyyy-mm-dd-kebab-slug.md');
    }
    final lines = f.readAsLinesSync();
    if (lines.length < 4 || !lines[0].startsWith('# Agent Note: ')) {
      _errors.add('$rel: 第一行必须是 "# Agent Note: <标题>"');
    }
    if (lines.length < 2 || lines[1].trim().isNotEmpty) {
      _errors.add('$rel: 第二行必须是空行');
    }
    final statusLine = lines.length > 2 ? lines[2] : '';
    final status = RegExp(
      r'^Status: (proposed|implemented|rejected)( — .+)?$',
    ).firstMatch(statusLine);
    if (status == null) {
      _errors.add('$rel: 第三行必须是 Status: proposed|implemented|rejected[ — 理由]');
    } else if (status.group(1) != lifecycle) {
      _errors.add('$rel: Status(${status.group(1)}) 与目录($lifecycle) 不一致');
    }
    final text = lines.join('\n');
    if (!text.contains('## Problem')) _errors.add('$rel: 缺少 ## Problem');
    if (!text.contains('## Alternatives considered')) {
      _errors.add('$rel: 缺少 ## Alternatives considered');
    }
    if (lifecycle == 'implemented') {
      if (!text.contains('## Decision')) {
        _errors.add('$rel: implemented 笔记缺少 ## Decision');
      }
      if (!text.contains('## Consequences')) {
        _errors.add('$rel: implemented 笔记缺少 ## Consequences');
      }
      for (final bad in [
        '## Proposal',
        '## Plan',
        '## Migration plan',
        '## Acceptance criteria',
        '## Risks',
      ]) {
        if (text.contains(bad)) _errors.add('$rel: implemented 笔记不得包含 $bad');
      }
    }
    if (lifecycle == 'proposed') {
      if (!text.contains('## Proposal')) {
        _errors.add('$rel: proposed 笔记缺少 ## Proposal');
      }
      if (!text.contains('## Acceptance criteria')) {
        _errors.add('$rel: proposed 笔记缺少 ## Acceptance criteria');
      }
      if (!text.contains('## Risks')) {
        _errors.add('$rel: proposed 笔记缺少 ## Risks');
      }
    }
    if (lifecycle == 'rejected' && !text.contains('## Proposal')) {
      _errors.add('$rel: rejected 笔记缺少 ## Proposal');
    }
  }
  _notes.add('Agent Note 格式：$count 篇');
}

// ---------- 技能元数据 ----------

void _verifySkills(Directory repo) {
  final dir = Directory('${repo.path}/.agents/skills');
  if (!dir.existsSync()) return;
  var count = 0;
  for (final entry in dir.listSync().whereType<Directory>()) {
    final skill = File('${entry.path}/SKILL.md');
    if (!skill.existsSync()) {
      _errors.add('${_rel(repo, entry.path)}: 缺少 SKILL.md');
      continue;
    }
    count++;
    final rel = _rel(repo, skill.path);
    final text = skill.readAsStringSync();
    final fm = RegExp(r'^---\n([\s\S]*?)\n---').firstMatch(text);
    if (fm == null) {
      _errors.add('$rel: 缺少 frontmatter');
      continue;
    }
    final body = fm.group(1)!;
    final name = RegExp(
      r'^name:\s*(.+)$',
      multiLine: true,
    ).firstMatch(body)?.group(1)?.trim();
    final desc = RegExp(
      r'^description:\s*(.+)$',
      multiLine: true,
    ).firstMatch(body)?.group(1)?.trim();
    if (name == null || name.isEmpty) _errors.add('$rel: frontmatter 缺少 name');
    if (name != null && name != entry.path.split('/').last) {
      _errors.add('$rel: name($name) 与目录名不一致');
    }
    if (desc == null || desc.length < 20) {
      _errors.add('$rel: description 太短或缺失');
    }
    if (desc != null && desc.length > 500) {
      _errors.add('$rel: description 超过 500 字符');
    }
  }
  _notes.add('技能元数据：$count 个');
}

// ---------- 预算 ----------

void _verifyBudgets(Directory repo) {
  final manifest = File('${repo.path}/$_budgetFile');
  if (!manifest.existsSync()) {
    _errors.add('$_budgetFile: 缺失');
    return;
  }
  final data = jsonDecode(manifest.readAsStringSync()) as Map<String, dynamic>;
  for (final entry in data.entries) {
    final f = File('${repo.path}/${entry.key}');
    if (!f.existsSync()) {
      _errors.add('$_budgetFile: 列出的文件不存在 -> ${entry.key}');
      continue;
    }
    final lines = _lineCount(f);
    final max = entry.value as int;
    if (lines > max) {
      _errors.add('${entry.key}: $lines 行，超过预算 $max 行');
    }
  }
  _notes.add('预算：${data.length} 份常驻文档');
}

// ---------- 禁用别称 ----------

/// 术语表的"禁用别称"列里，标识符形式的别称不得在 lib/ 里被声明为类型。
/// 中文别称与短语不参与机器校验，仍靠评审。
void _verifyBannedAliases(Directory repo) {
  final file = File('${repo.path}/docs/glossary.md');
  if (!file.existsSync()) return;
  final sources = <String>[];
  for (final f in Directory(
    '${repo.path}/lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    sources.add(f.readAsStringSync());
  }
  final haystack = sources.join('\n');
  var checked = 0;
  for (final line in file.readAsLinesSync()) {
    final t = line.trim();
    if (!t.startsWith('|')) continue;
    final cells = t.split('|');
    if (cells.length < 4) continue;
    for (final alias in cells[3].split(RegExp(r'[、,，]'))) {
      final name = alias.trim();
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]*$').hasMatch(name)) continue;
      checked++;
      final decl = RegExp(
        r'\b(class|enum|typedef|mixin|extension)\s+' +
            RegExp.escape(name) +
            r'\b',
      );
      if (decl.hasMatch(haystack)) {
        _errors.add('docs/glossary.md: 禁用别称 $name 在 lib/ 里被声明为类型');
      }
    }
  }
  _notes.add('禁用别称核对：$checked 个标识符');
}

// ---------- docs/ 页面以 Dev Note 收尾 ----------

void _verifyDevNotes(List<File> files) {
  var count = 0;
  for (final f in files) {
    final rel = _display(f);
    if (!rel.startsWith('docs/')) continue;
    count++;
    var lastSection = '';
    var inFence = false;
    for (final line in f.readAsLinesSync()) {
      if (line.trimLeft().startsWith('```')) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;
      if (line.startsWith('## ')) lastSection = line.trim();
    }
    if (lastSection != '## Dev Note') {
      _errors.add('$rel: 最后一节必须是 ## Dev Note（当前 $lastSection）');
    }
  }
  _notes.add('Dev Note 收尾：$count 份 docs 页面');
}
