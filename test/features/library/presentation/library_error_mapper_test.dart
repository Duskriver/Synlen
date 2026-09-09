import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:synlen/l10n/app_localizations.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';
import 'package:synlen/src/features/library/presentation/library_error_mapper.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('每个错误码在双语下都有非空文案', () {
    for (final code in LibraryErrorCode.values) {
      expect(libraryErrorMessage(en, code), isNotEmpty, reason: code.name);
      expect(libraryErrorMessage(zh, code), isNotEmpty, reason: code.name);
    }
  });

  test('DRM 拒绝映射为 DRM 专属文案', () {
    expect(
      libraryErrorMessage(zh, LibraryErrorCode.drmProtected),
      zh.importFailedDrm,
    );
    expect(
      libraryErrorMessage(en, LibraryErrorCode.drmProtected),
      en.importFailedDrm,
    );
  });

  test('备份版本过新映射为升级提示', () {
    expect(
      libraryErrorMessage(zh, LibraryErrorCode.backupVersionTooNew),
      zh.backupVersionTooNew,
    );
  });

  test('备份归档非法映射为归档校验文案', () {
    expect(
      libraryErrorMessage(zh, LibraryErrorCode.backupArchiveInvalid),
      zh.backupInvalidArchive,
    );
  });

  test('未知异常回退到场景通用文案，内部细节不上屏', () {
    final secret = StateError('private database details');
    expect(
      libraryErrorMessageFor(zh, secret, fallback: zh.importFailed),
      zh.importFailed,
    );
    expect(
      libraryErrorMessageFor(zh, secret, fallback: zh.restoreFailed),
      zh.restoreFailed,
    );
    // LibraryException 按码映射，details 不出现在文案里
    const typed = LibraryException(
      LibraryErrorCode.backupCorrupted,
      'private database details',
    );
    final message = libraryErrorMessageFor(
      zh,
      typed,
      fallback: zh.restoreFailed,
    );
    expect(message, zh.backupDataCorrupted);
    expect(message, isNot(contains('private database details')));
  });
}
