import 'dart:convert';

import 'imported_font.dart';

/// 已导入字体列表的持久化编解码：磁盘上只存文件名数组。
///
/// 解析容错：null、非法 JSON 与非字符串条目都回退为空列表或跳过，
/// 不让一条脏数据毁掉整个字体列表。
List<ImportedFont> decodeImportedFonts(String? jsonStr) {
  if (jsonStr == null) return [];
  try {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list.whereType<String>().map(ImportedFont.fromFileName).toList();
  } catch (_) {
    return [];
  }
}

String encodeImportedFonts(List<ImportedFont> fonts) =>
    jsonEncode(fonts.map((font) => font.fileName).toList());
