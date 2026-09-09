import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/src/core/file_handling/backup_archive_guard.dart';

void main() {
  BackupArchiveEntryInfo entry(String name, [int size = 1024]) =>
      (name: name, size: size);

  group('validateBackupArchiveEntries', () {
    test('正常备份条目全部通过', () {
      final result = validateBackupArchiveEntries([
        entry('shelf.json'),
        entry('books/abc.epub', 5 * 1024 * 1024),
        entry('manifests/abc.json'),
        entry('covers/abc.png'),
      ]);

      expect(result, isNull);
    });

    test('条目数超过上限', () {
      final entries = List.generate(
        maxBackupEntryCount + 1,
        (i) => entry('books/book_$i.epub'),
      );

      expect(
        validateBackupArchiveEntries(entries),
        BackupArchiveViolation.tooManyEntries,
      );
    });

    test('单条目大小超过上限', () {
      final result = validateBackupArchiveEntries([
        entry('books/huge.epub', maxBackupEntryBytes + 1),
      ]);

      expect(result, BackupArchiveViolation.entryTooLarge);
    });

    test('总解压量超过上限', () {
      // 每个条目恰好等于单条目上限，9 个累计超过 4 GiB 总量上限。
      final entries = List.generate(
        9,
        (i) => entry('books/big_$i.epub', maxBackupEntryBytes),
      );

      expect(
        validateBackupArchiveEntries(entries),
        BackupArchiveViolation.totalTooLarge,
      );
    });

    test('拒绝 ../ 越界路径', () {
      expect(
        validateBackupArchiveEntries([entry('../../evil.txt')]),
        BackupArchiveViolation.unsafePath,
      );
      expect(
        validateBackupArchiveEntries([entry('books/../../evil.txt')]),
        BackupArchiveViolation.unsafePath,
      );
    });

    test('拒绝绝对路径', () {
      expect(
        validateBackupArchiveEntries([entry('/etc/passwd')]),
        BackupArchiveViolation.unsafePath,
      );
      expect(
        validateBackupArchiveEntries([entry('C:/Windows/evil.dll')]),
        BackupArchiveViolation.unsafePath,
      );
      // 反斜杠形式的 .. 同样拒绝。
      expect(
        validateBackupArchiveEntries([entry('..\\..\\evil.txt')]),
        BackupArchiveViolation.unsafePath,
      );
    });

    test('拒绝空条目名', () {
      expect(
        validateBackupArchiveEntries([entry('')]),
        BackupArchiveViolation.unsafePath,
      );
    });

    test('恰好等于上限时放行', () {
      final result = validateBackupArchiveEntries([
        entry('books/exact.epub', maxBackupEntryBytes),
      ]);

      expect(result, isNull);
    });
  });
}
