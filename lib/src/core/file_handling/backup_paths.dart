import 'package:path/path.dart' as p;
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import 'platform_path.dart';

/// 备份里一本书的三个文件句柄；封面可缺。
class BackupPathsForBook {
  PlatformPath epubPath;
  PlatformPath manifestPath;
  PlatformPath? coverPath;

  BackupPathsForBook({
    required this.epubPath,
    required this.manifestPath,
    required this.coverPath,
  });
}

/// 一份备份的结构：根目录、书架文件与按哈希索引的书籍文件。
class BackupPaths {
  PlatformPath rootPath;
  PlatformPath shelfFile;
  Map<String, BackupPathsForBook> bookPaths; // Keyed by book hash

  BackupPaths({
    required this.rootPath,
    required this.shelfFile,
    required this.bookPaths,
  });
}

/// 备份来源里的一条文件记录。
///
/// [displayPath] 是解码后的绝对路径，只用于 basename / dirname 判断；
/// [platformPath] 是不透明句柄（[AndroidUriPath] 或 [IOSFilePath]），存入结果。
typedef BackupEntry = ({String displayPath, PlatformPath platformPath});

/// [classifyBackupEntries] 的分桶结果。
typedef ClassifiedBackup = ({
  PlatformPath? shelfFile,
  Map<String, Map<String, PlatformPath>> tempBookComponents,
});

/// 把备份文件条目按目标目录分成书架文件与「哈希 → 书籍组件」桶。
ClassifiedBackup classifyBackupEntries(List<BackupEntry> entries) {
  PlatformPath? shelfFile;
  final tempBookComponents = <String, Map<String, PlatformPath>>{};

  for (final entry in entries) {
    final fileName = p.basename(entry.displayPath);
    final parentDirName = p.basename(p.dirname(entry.displayPath));
    if (fileName.isEmpty) continue;

    if (fileName == AppStorageConstants.shelfFile) {
      shelfFile = entry.platformPath;
      continue;
    }

    if (parentDirName == AppStorageConstants.booksDir &&
        (fileName.endsWith('.epub') || fileName.endsWith('.txt'))) {
      final dotIndex = fileName.lastIndexOf('.');
      final hash = fileName.substring(0, dotIndex);
      tempBookComponents.putIfAbsent(hash, () => {})['epub'] =
          entry.platformPath;
    } else if (parentDirName == AppStorageConstants.manifestsDir &&
        fileName.endsWith('.json')) {
      final hash = fileName.replaceAll('.json', '');
      tempBookComponents.putIfAbsent(hash, () => {})['manifest'] =
          entry.platformPath;
    } else if (parentDirName == AppStorageConstants.coversDir) {
      final extIndex = fileName.lastIndexOf('.');
      if (extIndex != -1) {
        final hash = fileName.substring(0, extIndex);
        tempBookComponents.putIfAbsent(hash, () => {})['cover'] =
            entry.platformPath;
      }
    }
  }

  return (shelfFile: shelfFile, tempBookComponents: tempBookComponents);
}

/// 由组件桶装配书籍路径，缺少书文件或清单的条目跳过并记日志。
Map<String, BackupPathsForBook> buildBackupBookPaths(
  Map<String, Map<String, PlatformPath>> components,
) {
  final result = <String, BackupPathsForBook>{};
  for (final entry in components.entries) {
    final c = entry.value;
    if (c.containsKey('epub') && c.containsKey('manifest')) {
      result[entry.key] = BackupPathsForBook(
        epubPath: c['epub']!,
        manifestPath: c['manifest']!,
        coverPath: c['cover'],
      );
    } else {
      appLogger.w(
        'Warning: Missing epub or manifest for hash ${entry.key}, skipping.',
      );
    }
  }
  return result;
}
