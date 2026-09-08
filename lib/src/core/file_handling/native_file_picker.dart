import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:synlen/src/core/services/app_logger.dart';
import 'package:synlen/src/core/storage/app_storage_constants.dart';

import 'backup_paths.dart';
import 'platform_path.dart';

/// 平台原生文件选择器适配。
///
/// 只负责 MethodChannel 调用与平台分支（Android SAF / iOS UIDocumentPicker），
/// 不碰导入缓存、哈希与落盘；这些属于 [UnifiedImportService]。
class NativeFilePicker {
  static const String _channelName = 'com.tanglei.synlen/native_picker';
  static final MethodChannel _channel = MethodChannel(_channelName);

  /// Pick multiple EPUB files using platform-appropriate picker
  ///
  /// Android: Uses native SAF document picker via MethodChannel
  /// iOS: Currently unsupported - returns empty list
  ///
  /// Returns a list of [PlatformPath] objects representing selected files.
  /// Returns empty list if user cancels or no files are selected.
  Future<List<PlatformPath>> pickFiles() async {
    if (Platform.isAndroid) {
      return await _pickFilesAndroid();
    } else if (Platform.isIOS) {
      return await _pickFilesIOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// Pick a folder and recursively scan for EPUB files
  ///
  /// Android: Uses native SAF tree picker with background traversal via MethodChannel
  /// iOS: Currently unsupported - returns empty list
  ///
  /// Returns a list of [PlatformPath] objects for all EPUB files found.
  /// Returns empty list if user cancels or no EPUB files are found.
  Future<List<PlatformPath>> pickFolder() async {
    if (Platform.isAndroid) {
      return await _pickFolderAndroid();
    } else if (Platform.isIOS) {
      return await _pickFolderIOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// 查询 SAF 文档的显示名；失败返回 null（由调用方沿用 URI 推断结果）
  Future<String?> resolveDisplayName(String uri) async {
    try {
      return await _channel.invokeMethod<String>('getDisplayName', uri);
    } on PlatformException catch (e) {
      appLogger.w('getDisplayName failed: ${e.message}');
      return null;
    }
  }

  /// Asks Swift to copy [originalPath] (inside the active security scope)
  /// to a fresh unique file in `NSTemporaryDirectory()` and returns the
  /// resulting absolute temp path.
  ///
  /// iOS only.  On other platforms this is a no-op that returns the original
  /// path unchanged.
  Future<String> fetchIosFileToTemp(String originalPath) async {
    if (!Platform.isIOS) return originalPath;
    final tempPath = await _channel.invokeMethod<String>(
      'fetchIosFile',
      originalPath,
    );
    return tempPath ?? originalPath;
  }

  /// Releases all security-scoped resource accesses held on the native side.
  ///
  /// **Must** be called in the `finally` block of any iOS pick+process
  /// operation to prevent resource leaks.
  Future<void> releaseIosAccess() async {
    if (Platform.isIOS) {
      await _channel.invokeMethod<void>('releaseIosAccess');
    }
  }

  /// Pick a backup directory and return its real filesystem path.
  ///
  /// Android: Invokes the native `pickBackupFolder` channel method which
  ///          presents ACTION_OPEN_DOCUMENT_TREE and converts the SAF tree
  ///          URI to an absolute path so [File] API works directly.
  /// iOS:     Not yet implemented — returns null.
  ///
  /// Returns null if the user cancels or the path cannot be resolved.
  Future<BackupPaths?> pickBackupFolder() async {
    if (Platform.isAndroid) {
      return await _pickBackupFolderAndroid();
    } else if (Platform.isIOS) {
      return await _pickBackupFolderIOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// Pick a single backup ZIP archive.
  ///
  /// Android: SAF document picker filtered to ZIP MIME types.
  /// iOS:     Document picker restricted to the zip UTType; the file stays
  ///          security-scoped until [releaseIosAccess].
  ///
  /// Returns null if the user cancels.
  Future<PlatformPath?> pickBackupZipFile() async {
    if (Platform.isAndroid) {
      return await _pickBackupZipFileAndroid();
    } else if (Platform.isIOS) {
      return await _pickBackupZipFileIOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  Future<PlatformPath?> _pickBackupZipFileAndroid() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBackupFile',
      );
      if (result == null || result.isEmpty) return null;
      return AndroidUriPath(result.whereType<String>().first);
    } on PlatformException catch (e) {
      appLogger.e('Android backup file picker error: ${e.message}');
      return null;
    }
  }

  Future<PlatformPath?> _pickBackupZipFileIOS() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBackupFile',
      );
      if (result == null || result.isEmpty) return null;
      return IOSFilePath(result.whereType<String>().first);
    } on PlatformException catch (e) {
      appLogger.e('iOS backup file picker error: ${e.message}');
      return null;
    }
  }

  /// Pick multiple font files (.ttf / .otf) using platform-appropriate picker.
  ///
  /// Android: Uses native SAF document picker via MethodChannel.
  /// iOS: Uses UIDocumentPickerViewController restricted to font UTTypes.
  ///
  /// Returns a list of [PlatformPath] objects representing selected files.
  /// Returns empty list if user cancels or no files are selected.
  Future<List<PlatformPath>> pickFontFiles() async {
    if (Platform.isAndroid) {
      return await _pickFontFilesAndroid();
    } else if (Platform.isIOS) {
      return await _pickFontFilesIOS();
    } else {
      throw UnsupportedError('Platform not supported');
    }
  }

  /// Android: Pick files using native SAF via MethodChannel
  Future<List<PlatformPath>> _pickFilesAndroid() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBookFiles',
      );

      if (result == null) {
        return [];
      }

      return result
          .whereType<String>()
          .map((uri) => AndroidUriPath(uri))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('Android file picker error: ${e.message}');
      return [];
    }
  }

  /// Android: Pick folder using native SAF with background traversal
  Future<List<PlatformPath>> _pickFolderAndroid() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBookFolder',
      );

      if (result == null) {
        return [];
      }

      return result
          .whereType<String>()
          .map((uri) => AndroidUriPath(uri))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('Android folder picker error: ${e.message}');
      return [];
    }
  }

  Future<BackupPaths?> _pickBackupFolderAndroid() async {
    final result = await _channel.invokeMethod<List<Object?>>(
      'pickBackupFolder',
    );
    if (result == null || result.isEmpty) return null;

    final entries = result.whereType<String>().map((uriString) {
      final decoded = Uri.decodeFull(uriString);
      return (
        displayPath: decoded,
        platformPath: AndroidUriPath(uriString) as PlatformPath,
      );
    }).toList();

    final classified = classifyBackupEntries(entries);

    if (classified.shelfFile == null) {
      throw Exception(
        'Invalid backup: ${AppStorageConstants.shelfFile} not found',
      );
    }

    final bookPaths = buildBackupBookPaths(classified.tempBookComponents);
    final shelfUri = Uri.decodeFull(
      (classified.shelfFile! as AndroidUriPath).uri,
    );

    return BackupPaths(
      rootPath: AndroidUriPath(p.dirname(shelfUri)),
      shelfFile: classified.shelfFile!,
      bookPaths: bookPaths,
    );
  }

  /// iOS: Pick multiple EPUB files (lazy – security scope retained by Swift).
  Future<List<PlatformPath>> _pickFilesIOS() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBookFiles',
      );
      if (result == null) return [];
      return result
          .whereType<String>()
          .map((path) => IOSFilePath(path))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('iOS file picker error: ${e.message}');
      return [];
    }
  }

  /// iOS: Pick EPUB-containing folder (lazy – security scope retained by Swift).
  Future<List<PlatformPath>> _pickFolderIOS() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickBookFolder',
      );
      if (result == null) return [];
      return result
          .whereType<String>()
          .map((path) => IOSFilePath(path))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('iOS folder picker error: ${e.message}');
      return [];
    }
  }

  /// iOS: Pick backup folder and parse its structure (lazy – scope retained).
  Future<BackupPaths?> _pickBackupFolderIOS() async {
    final result = await _channel.invokeMethod<List<Object?>>(
      'pickBackupFolder',
    );
    if (result == null || result.isEmpty) return null;

    final entries = result.whereType<String>().map((pathStr) {
      return (
        displayPath: pathStr,
        platformPath: IOSFilePath(pathStr) as PlatformPath,
      );
    }).toList();

    final classified = classifyBackupEntries(entries);

    if (classified.shelfFile == null) {
      throw Exception(
        'Invalid backup: ${AppStorageConstants.shelfFile} not found',
      );
    }

    final bookPaths = buildBackupBookPaths(classified.tempBookComponents);
    final rootPath = IOSFilePath(
      p.dirname((classified.shelfFile! as IOSFilePath).path),
    );

    return BackupPaths(
      rootPath: rootPath,
      shelfFile: classified.shelfFile!,
      bookPaths: bookPaths,
    );
  }

  /// Android: Pick font files (.ttf / .otf) using native SAF via MethodChannel.
  Future<List<PlatformPath>> _pickFontFilesAndroid() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickFontFiles',
      );
      if (result == null) return [];
      return result
          .whereType<String>()
          .map((uri) => AndroidUriPath(uri))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('Android font picker error: ${e.message}');
      return [];
    }
  }

  /// iOS: Pick font files (.ttf / .otf) (lazy – security scope retained by Swift).
  Future<List<PlatformPath>> _pickFontFilesIOS() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>(
        'pickFontFiles',
      );
      if (result == null) return [];
      return result
          .whereType<String>()
          .map((path) => IOSFilePath(path))
          .toList();
    } on PlatformException catch (e) {
      appLogger.e('iOS font picker error: ${e.message}');
      return [];
    }
  }
}
