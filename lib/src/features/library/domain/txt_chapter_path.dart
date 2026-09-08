/// TXT 虚拟章节路径契约：`txt/chapter_N.xhtml`。
///
/// 导入时 [TxtBookParser] 按此格式写入 spine 与 TOC 的 href，阅读时内容供给按同一
/// 格式解析章节索引。契约两端分属 library 与 reader，故与解析器实现分开放进 domain。
const String txtChapterPathPrefix = 'txt/chapter_';
const String txtChapterPathSuffix = '.xhtml';

/// 从虚拟章节路径解析 spine 索引；路径不符合契约时返回 null。
int? txtChapterIndexFromPath(String relativePath) {
  final match = RegExp(
    '^${RegExp.escape(txtChapterPathPrefix)}(\\d+)${RegExp.escape(txtChapterPathSuffix)}\$',
  ).firstMatch(relativePath);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}
