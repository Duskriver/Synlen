import '../../../../l10n/app_localizations.dart';
import '../domain/library_exception.dart';

/// [LibraryErrorCode] → 用户可读文案；[LibraryException.details] 仅入日志，不上屏。
String libraryErrorMessage(AppLocalizations l10n, LibraryErrorCode code) =>
    switch (code) {
      LibraryErrorCode.fileUnreadable => l10n.importFileUnreadable,
      LibraryErrorCode.parseFailed => l10n.importParseFailed,
      LibraryErrorCode.drmProtected => l10n.importFailedDrm,
      LibraryErrorCode.duplicateBook => l10n.importDuplicateBook,
      LibraryErrorCode.fileWriteFailed => l10n.importFileWriteFailed,
      LibraryErrorCode.saveFailed => l10n.importSaveFailed,
      LibraryErrorCode.importFailed => l10n.importFailed,
      LibraryErrorCode.backupVersionTooNew => l10n.backupVersionTooNew,
      LibraryErrorCode.backupArchiveInvalid => l10n.backupInvalidArchive,
      LibraryErrorCode.backupCorrupted => l10n.backupDataCorrupted,
      LibraryErrorCode.restoreFailed => l10n.restoreFailed,
    };

/// 未知异常回退为通用文案；[LibraryException] 按错误码映射。
/// [fallback] 按场景区分（导入用 `l10n.importFailed`，恢复用 `l10n.restoreFailed`）。
String libraryErrorMessageFor(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
}) => error is LibraryException
    ? libraryErrorMessage(l10n, error.code)
    : fallback;
