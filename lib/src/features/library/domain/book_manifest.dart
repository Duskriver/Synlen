/// EPUB 结构模型（纯 Dart，无数据库依赖）。
library;

/// 这些嵌套对象（脊项/清单项/目录项）通过 JSON 序列化存储在
/// [BookManifest] 数据库行的 text 列中。

/// 文件引用：路径 + 可选锚点
class Href {
  String path;
  String anchor;

  Href({this.path = '', this.anchor = 'top'});

  factory Href.fromJson(Map<String, dynamic> json) => Href(
    path: json['path'] as String? ?? '',
    anchor: json['anchor'] as String? ?? 'top',
  );

  Map<String, dynamic> toJson() => {'path': path, 'anchor': anchor};

  @override
  bool operator ==(Object other) {
    return other is Href && other.path == path && other.anchor == anchor;
  }

  @override
  int get hashCode => Object.hash(path, anchor);

  @override
  String toString() => '$path#$anchor';
}

/// 单个脊项：OPF spine 中的线性阅读顺序条目
class SpineItem {
  int index;
  String href;
  String idref;
  bool linear;
  String? properties;

  SpineItem({
    this.index = 0,
    this.href = '',
    this.idref = '',
    this.linear = true,
    this.properties,
  });

  factory SpineItem.fromJson(Map<String, dynamic> json) => SpineItem(
    index: json['index'] as int? ?? 0,
    href: json['href'] as String? ?? '',
    idref: json['idref'] as String? ?? '',
    linear: json['linear'] as bool? ?? true,
    properties: json['properties'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'index': index,
    'href': href,
    'idref': idref,
    'linear': linear,
    if (properties != null) 'properties': properties,
  };
}

/// 单个清单项：OPF manifest 中的文件引用
class ManifestItem {
  String id;
  Href href;
  String mediaType;
  String? properties;

  ManifestItem({this.id = '', Href? href, this.mediaType = '', this.properties})
    : href = href ?? Href();

  factory ManifestItem.fromJson(Map<String, dynamic> json) => ManifestItem(
    id: json['id'] as String? ?? '',
    href: Href.fromJson(json['href'] as Map<String, dynamic>? ?? const {}),
    mediaType: json['mediaType'] as String? ?? '',
    properties: json['properties'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'href': href.toJson(),
    'mediaType': mediaType,
    if (properties != null) 'properties': properties,
  };
}

/// 目录项：导航树条目（纯层级导航，无需覆盖每个脊项）
class TocItem {
  int id;
  String label;
  Href href;
  int depth;

  /// 对应 spine 中的索引；-1 表示不对应任何脊项起点（如深层链接）
  int spineIndex;
  int parentId;
  List<TocItem> children;

  TocItem({
    this.id = 0,
    this.label = '',
    Href? href,
    this.depth = 0,
    this.spineIndex = -1,
    this.parentId = -1,
    List<TocItem>? children,
  }) : href = href ?? Href(),
       children = children ?? [];

  factory TocItem.fromJson(Map<String, dynamic> json) => TocItem(
    id: json['id'] as int? ?? 0,
    label: json['label'] as String? ?? '',
    href: Href.fromJson(json['href'] as Map<String, dynamic>? ?? const {}),
    depth: json['depth'] as int? ?? 0,
    spineIndex: json['spineIndex'] as int? ?? -1,
    parentId: json['parentId'] as int? ?? -1,
    children: (json['children'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(TocItem.fromJson)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'href': href.toJson(),
    'depth': depth,
    'spineIndex': spineIndex,
    'parentId': parentId,
    'children': children.map((c) => c.toJson()).toList(),
  };

  /// 展平为列表（不含空 href 的条目）
  List<TocItem> flatten() {
    final result = <TocItem>[];
    if (href.path.isNotEmpty) {
      result.add(this);
    }
    for (final child in children) {
      result.addAll(child.flatten());
    }
    return result;
  }

  /// 展平为列表（包含自身，即使 href 为空）
  List<TocItem> safeFlatten() {
    final result = <TocItem>[this];
    for (final child in children) {
      result.addAll(child.safeFlatten());
    }
    return result;
  }
}
