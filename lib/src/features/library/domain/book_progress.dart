import 'dart:convert';

/// 完整阅读定位及书架百分比；定位内容不依赖具体阅读器 SDK 的类型。
class BookProgress {
  const BookProgress._(this.locatorJson, this.fraction);

  /// 原样保留位置、文本上下文及 SDK 扩展字段。
  final String locatorJson;
  final double fraction;

  factory BookProgress.fromLocator(
    Map<String, dynamic> locator, {
    double? fraction,
  }) {
    if (locator['href'] is! String ||
        (locator['href'] as String).isEmpty ||
        locator['type'] is! String) {
      throw const FormatException('阅读定位缺少 href 或 type');
    }
    final locations = locator['locations'];
    final total = locations is Map ? locations['totalProgression'] : null;
    final value = fraction ?? (total is num ? total.toDouble() : 0.0);
    if (!value.isFinite) {
      throw const FormatException('阅读百分比必须是有限数值');
    }
    return BookProgress._(jsonEncode(locator), value.clamp(0.0, 1.0));
  }

  factory BookProgress.fromJson(Map<String, dynamic> json) =>
      BookProgress.fromLocator(
        Map<String, dynamic>.from(json['locator'] as Map),
        fraction: (json['fraction'] as num).toDouble(),
      );

  /// 返回独立副本，调用方修改 SDK 参数不会改变已保存的位置。
  Map<String, dynamic> get locator =>
      jsonDecode(locatorJson) as Map<String, dynamic>;

  String? get chapterTitle => locator['title'] as String?;

  Map<String, dynamic> toJson() => {'locator': locator, 'fraction': fraction};

  @override
  bool operator ==(Object other) =>
      other is BookProgress &&
      other.locatorJson == locatorJson &&
      other.fraction == fraction;

  @override
  int get hashCode => Object.hash(locatorJson, fraction);
}
