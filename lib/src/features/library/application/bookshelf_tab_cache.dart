import 'package:synlen/src/core/database/app_database.dart';

/// 书架标签页的 LRU 缓存。
///
/// 每个分组保留最近一次查询结果，切回标签页时无需重复查库；最多保留
/// [maxTabs] 个分组，超出时淘汰最久未使用的一项。淘汰顺序不进入
/// [BookshelfState]，它是 UI 不需要读的内部细节。
class BookshelfTabCache {
  BookshelfTabCache({this.maxTabs = 8});

  final int maxTabs;

  final List<int?> _order = [];
  final Map<int?, List<ShelfBook>> _entries = {};

  /// 写入某分组的书籍并标记最近使用，返回淘汰后的快照。
  Map<int?, List<ShelfBook>> put(int? key, List<ShelfBook> books) {
    _entries[key] = books;
    _order
      ..remove(key)
      ..add(key);
    while (_order.length > maxTabs) {
      _entries.remove(_order.removeAt(0));
    }
    return Map<int?, List<ShelfBook>>.from(_entries);
  }

  /// 移除某个分组的缓存（分组被删除时），返回剩余快照。
  Map<int?, List<ShelfBook>> remove(int? key) {
    _order.remove(key);
    _entries.remove(key);
    return Map<int?, List<ShelfBook>>.from(_entries);
  }
}
