/// TXT 标题行判定规则。
///
/// 导入时的章节切分与阅读时的章节首行渲染共用同一套规则，故与切分算法分开
/// 放进 domain：两边各引一份规则，判定结果必须一致。
library;

/// 标题行最大长度（trim 后），防止把正文误判为标题。
const int maxTxtHeadingLength = 50;

/// 卷级标题（层级 > 章）：第X卷
final RegExp _volumeHeading = RegExp(
  r'^\s*第[0-9０-９一二三四五六七八九十百千万两零〇]{1,9}\s*卷'
  r'([：:、．.\-—\s]+.{0,40})?\s*$',
);

/// 章级标题：第X章/回/节/集/部/篇
final RegExp _chapterHeading = RegExp(
  r'^\s*第[0-9０-９一二三四五六七八九十百千万两零〇]{1,9}\s*[章节回集部篇]'
  r'([：:、．.\-—\s]+.{0,40})?\s*$',
);

/// 英文章节标题：Chapter N
final RegExp _englishChapterHeading = RegExp(
  r'^\s*chapter\s+[0-9]{1,5}([：:、．.\-—\s]+.{0,40})?\s*$',
  caseSensitive: false,
);

/// 特殊独立标题行（整行匹配，番外/外传允许短后缀）
final RegExp _specialHeading = RegExp(
  r'^\s*(楔子|引子|序言?|序章|前言|自序|后记|终章|尾声|作者的话|'
  r'番外[：:、．.\-—\s].{0,30}|外传[：:、．.\-—\s].{0,30})\s*$',
);

/// 纯数字标题行（部分英文/网文 TXT 用 1、2、3 分章）
final RegExp _numberHeading = RegExp(r'^\s*\d{1,4}\s*$');

/// 判断一行是否为标题行；空白行与超长行一律不是。
bool isTxtHeadingLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.length > maxTxtHeadingLength) return false;
  return _volumeHeading.hasMatch(trimmed) ||
      _chapterHeading.hasMatch(trimmed) ||
      _englishChapterHeading.hasMatch(trimmed) ||
      _specialHeading.hasMatch(trimmed) ||
      _numberHeading.hasMatch(trimmed);
}

/// 判断一行是否为卷级标题；卷级只影响 TOC 层级，不影响内容切片。
bool isTxtVolumeHeading(String line) => _volumeHeading.hasMatch(line);
