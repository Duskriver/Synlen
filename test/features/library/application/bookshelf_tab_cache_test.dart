import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/application/bookshelf_tab_cache.dart';
import 'package:synlen/src/features/library/domain/book_views.dart';

ShelfBookView buildBook(int id) => (
  id: id,
  fileHash: 'hash$id',
  title: '书$id',
  author: '作者',
  coverPath: null,
  readingProgress: 0,
  isFinished: false,
  isDeleted: false,
);

void main() {
  test('写入后返回包含该分组的快照', () {
    final cache = BookshelfTabCache();

    final snapshot = cache.put(1, [buildBook(1)]);

    expect(snapshot.keys, [1]);
    expect(snapshot[1]!.single.id, 1);
  });

  test('超过上限时淘汰最久未使用的分组', () {
    final cache = BookshelfTabCache(maxTabs: 2);
    cache.put(1, [buildBook(1)]);
    cache.put(2, [buildBook(2)]);

    final snapshot = cache.put(3, [buildBook(3)]);

    expect(snapshot.keys, containsAll([2, 3]));
    expect(snapshot.containsKey(1), isFalse);
  });

  test('再次写入已有分组会刷新它的最近使用顺序', () {
    final cache = BookshelfTabCache(maxTabs: 2);
    cache.put(1, [buildBook(1)]);
    cache.put(2, [buildBook(2)]);
    cache.put(1, [buildBook(1)]);

    final snapshot = cache.put(3, [buildBook(3)]);

    expect(snapshot.containsKey(1), isTrue);
    expect(snapshot.containsKey(2), isFalse);
  });

  test('null 分组（全部）与普通分组互不影响', () {
    final cache = BookshelfTabCache(maxTabs: 2);
    cache.put(null, [buildBook(1)]);
    cache.put(1, [buildBook(2)]);

    final snapshot = cache.put(2, [buildBook(3)]);

    expect(snapshot.containsKey(null), isFalse);
    expect(snapshot.keys, containsAll([1, 2]));
  });

  test('remove 移除指定分组并返回剩余快照', () {
    final cache = BookshelfTabCache();
    cache.put(1, [buildBook(1)]);
    cache.put(2, [buildBook(2)]);

    final snapshot = cache.remove(1);

    expect(snapshot.containsKey(1), isFalse);
    expect(snapshot.containsKey(2), isTrue);
  });

  test('返回的快照与内部缓存解耦', () {
    final cache = BookshelfTabCache();
    final snapshot = cache.put(1, [buildBook(1)]);

    cache.put(2, [buildBook(2)]);

    expect(snapshot.containsKey(2), isFalse);
  });
}
