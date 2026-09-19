import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/features/library/data/services/book_file_changes.dart';

void main() {
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('synlen-file-changes-'),
  );
  tearDown(() async => root.delete(recursive: true));
  test('失败恢复旧文件并清理新文件，已有原书不被删除', () async {
    final existing = await File('${root.path}/old').writeAsBytes([1, 2]);
    final created = File('${root.path}/new');
    final changes = BookFileChanges();
    await changes.write(existing, [3]);
    await changes.write(existing, [4]);
    await changes.write(created, [5]);
    await changes.close();
    expect(await existing.readAsBytes(), [1, 2]);
    expect(await created.exists(), isFalse);
    expect(await root.list().length, 1);
  });
  test('提交保留结果，清理补偿副本；复制不存在的源文件也能回滚', () async {
    final target = await File('${root.path}/target').writeAsBytes([1]);
    final changes = BookFileChanges();
    await changes.write(target, [2]);
    changes.commit();
    await changes.close();
    expect(await target.readAsBytes(), [2]);
    expect(await root.list().length, 1);
    final failed = BookFileChanges();
    await expectLater(
      failed.copyIfMissing(
        File('${root.path}/missing'),
        File('${root.path}/new'),
      ),
      throwsA(isA<FileSystemException>()),
    );
    await failed.close();
    expect(await root.list().length, 1);
  });
  test('跳过写入失败并提交其他修改时仍保留原件', () async {
    final target = await File('${root.path}/cover').writeAsBytes([1, 2]);
    final changes = BookFileChanges();
    await expectLater(
      changes.write(target, ['invalid'].cast<int>()),
      throwsA(isA<TypeError>()),
    );
    await changes.write(File('${root.path}/other'), [3]);
    changes.commit();
    await changes.close();
    expect(await target.readAsBytes(), [1, 2]);
    expect(await File('${root.path}/other').readAsBytes(), [3]);
    expect(await root.list().length, 2);
  });
}
