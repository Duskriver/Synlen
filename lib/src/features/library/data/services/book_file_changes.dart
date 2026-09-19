import 'dart:io';
import 'package:synlen/src/core/services/app_logger.dart';

/// 单本导入的文件补偿作用域：提交前失败恢复旧文件，只删除本次新建的文件。
class BookFileChanges {
  final _originals = <String, File?>{};
  final _backups = <Directory>[];
  bool _committed = false;

  Future<void> _remember(File target) async {
    if (_originals.containsKey(target.path)) return;
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      final dir = await target.parent.createTemp('.synlen-rollback-');
      _backups.add(dir);
      _originals[target.path] = await target.copy('${dir.path}/original');
    } else {
      _originals[target.path] = null;
    }
  }

  Future<void> copyIfMissing(
    File source,
    File target, {
    bool moveSource = false,
  }) async {
    if (await target.exists()) return;
    await _remember(target);
    if (moveSource) {
      try {
        await source.rename(target.path);
        return;
      } on FileSystemException {
        // 跨文件系统移动不可用时回退到复制。
      }
    }
    await source.copy(target.path);
  }

  Future<void> write(File target, List<int> bytes) async {
    await _remember(target);
    // 写入失败可被调用方跳过；原件只能在完整写入后替换。
    final staging = await target.parent.createTemp('.synlen-write-');
    try {
      final replacement = File('${staging.path}/replacement');
      await replacement.writeAsBytes(bytes, flush: true);
      await replacement.rename(target.path);
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (error) {
        appLogger.w('写入临时文件清理失败：$error');
      }
    }
  }

  /// 只在书目与清单的数据库事务成功后调用。
  void commit() => _committed = true;

  Future<void> close() async {
    var restored = true;
    if (!_committed) {
      for (final entry in _originals.entries.toList().reversed) {
        try {
          if (entry.value case final File original) {
            await original.copy(entry.key);
          } else {
            final created = File(entry.key);
            if (await created.exists()) await created.delete();
          }
        } catch (error, stack) {
          restored = false;
          appLogger.e(
            '恢复导入前文件失败：${entry.key}',
            error: error,
            stackTrace: stack,
          );
        }
      }
    }
    // 补偿失败时保留原件副本，避免丢失唯一可恢复的数据。
    if (!restored) throw FileSystemException('无法恢复导入前的文件');
    for (final directory in _backups) {
      try {
        await directory.delete(recursive: true);
      } catch (error) {
        appLogger.w('导入临时副本清理失败：$error');
      }
    }
    _originals.clear();
    _backups.clear();
  }
}
