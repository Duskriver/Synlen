import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synlen/src/core/file_handling/file_handling.dart';
import 'package:synlen/src/features/library/domain/library_exception.dart';
import 'package:synlen/src/features/library/presentation/library_error_mapper.dart';
import 'package:synlen/src/features/library/presentation/widgets/import_progress_dialog.dart';
import 'package:synlen/src/features/library/presentation/widgets/restore_progress_dialog.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../core/services/toast_service.dart';
import '../../application/bookshelf_notifier.dart';
import '../../application/library_notifier.dart';
import '../../../../core/providers/unified_import_service_provider.dart';
import '../widgets/delete_books_confirm_dialog.dart';
import '../widgets/group_name_prompt_dialog.dart';
import '../widgets/group_selection_dialog.dart';
import '../widgets/restore_source_dialog.dart';

/// Mixin that provides action methods for LibraryScreen.
/// Handles imports, deletions, group management, and file operations.
mixin LibraryActionsMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _isSelectingFiles = false;

  bool get isSelectingFiles => _isSelectingFiles;

  set isSelectingFiles(bool value) {
    if (mounted) {
      setState(() {
        _isSelectingFiles = value;
      });
    }
  }

  Future<void> _importPaths(
    BuildContext context,
    WidgetRef ref,
    List<PlatformPath> paths,
    Function() onImportablesReady,
  ) async {
    if (paths.isEmpty) {
      onImportablesReady();
      return;
    }

    // Process files one by one
    onImportablesReady();

    final stream = ref
        .read(libraryProvider.notifier)
        .importPipelineStream(paths);

    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.5),
      builder: (ctx) => ImportProgressDialog(stream: stream, l10n: l10n),
    );

    // Clean all temporary files after import is done
    ref.read(unifiedImportServiceProvider).clearAllCache();

    if (context.mounted) {
      await ref.read(bookshelfProvider.notifier).refresh();
    }
  }

  Future<void> handleScanFolder(BuildContext context, WidgetRef ref) async {
    try {
      isSelectingFiles = true;

      // Use unified import service for cross-platform file picking
      final importService = ref.read(unifiedImportServiceProvider);
      final paths = await importService.pickFolder();

      if (context.mounted) {
        await _importPaths(context, ref, paths, () {
          isSelectingFiles = false;
        });
      }
    } catch (e) {
      isSelectingFiles = false;
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ToastService.showError(
          libraryErrorMessageFor(l10n, e, fallback: l10n.importFailed),
        );
      }
    }
  }

  Future<void> handleImportFiles(BuildContext context, WidgetRef ref) async {
    try {
      isSelectingFiles = true;

      // Use unified import service for cross-platform file picking
      final importService = ref.read(unifiedImportServiceProvider);
      final paths = await importService.pickFiles();

      if (context.mounted) {
        await _importPaths(context, ref, paths, () {
          isSelectingFiles = false;
        });
      }
    } catch (e) {
      isSelectingFiles = false;
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ToastService.showError(
          libraryErrorMessageFor(l10n, e, fallback: l10n.importFailed),
        );
      }
    }
  }

  Future<void> confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteBooksConfirmDialog(),
    );

    if (confirmed == true) {
      final success = await ref
          .read(bookshelfProvider.notifier)
          .deleteSelected();
      if (context.mounted) {
        if (success) {
          ToastService.showSuccess(AppLocalizations.of(context)!.deleted);
        } else {
          ToastService.showError(AppLocalizations.of(context)!.failedToDelete);
        }
      }
    }
  }

  Future<void> showMoveToGroup(
    BuildContext context,
    WidgetRef ref,
    BookshelfState state,
  ) async {
    const createGroupResult = -2;

    final l10n = AppLocalizations.of(context)!;

    var result = await showDialog<int?>(
      context: context,
      builder: (context) => GroupSelectionDialog(
        groups: [
          for (final group in state.availableGroups)
            (id: group.id, name: group.name),
        ],
        createGroupResult: createGroupResult,
      ),
    );
    String? newName;

    if (result == createGroupResult) {
      if (!context.mounted) return;
      final name = await promptForGroupName(context);
      if (!context.mounted) return;
      if (name != null && name.trim().isNotEmpty) {
        final groupId = await ref
            .read(bookshelfProvider.notifier)
            .createGroup(name);
        if (!context.mounted) return;

        if (groupId == null) {
          if (state is AsyncError) {
            ToastService.showError(l10n.failedToCreateCategory);
          }
          return;
        } else {
          ToastService.showSuccess(l10n.categoryCreated(name));
        }

        result = groupId;
        newName = name;
      } else {
        if (name != null && name.trim().isEmpty) {
          ToastService.showError(l10n.categoryNameCannotBeEmpty);
        }
        return;
      }
    }

    if (result != null) {
      final targetGroupId = result == -1 ? null : result;
      final success = await ref
          .read(bookshelfProvider.notifier)
          .moveSelectedItems(targetGroupId);
      if (!context.mounted) return;
      {
        if (success) {
          var targetName = l10n.categoryName;
          if (targetGroupId == null) {
            targetName = l10n.uncategorized;
          } else {
            if (newName != null) {
              targetName = newName;
            } else {
              for (final group in state.availableGroups) {
                if (group.id == targetGroupId) {
                  targetName = group.name;
                  break;
                }
              }
            }
          }
          ToastService.showSuccess(l10n.movedTo(targetName));
        } else {
          ToastService.showError(l10n.failedToMove);
        }
      }
    }
  }

  Future<void> showEditGroupDialog(
    BuildContext context,
    WidgetRef ref,
    GroupOption group,
    AppLocalizations l10n,
  ) async {
    var draftName = group.name;
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.editCategory),
        content: TextFormField(
          initialValue: group.name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.categoryName,
          ),
          onChanged: (value) => draftName = value,
          onFieldSubmitted: (value) => Navigator.pop(context, value.trim()),
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final result = await ref
                  .read(bookshelfProvider.notifier)
                  .deleteGroup(group.id);
              if (context.mounted) {
                if (result) {
                  ToastService.showSuccess(l10n.categoryDeleted(group.name));
                } else {
                  ToastService.showError(l10n.failedToDeleteCategory);
                }
              }
            },
            child: Text(l10n.delete),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draftName.trim()),
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != group.name) {
      await ref.read(bookshelfProvider.notifier).renameGroup(group.id, result);
    }
  }

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  /// 触发完整书库恢复：先选来源（ZIP 文件或旧版文件夹），再走各自的
  /// 选取流程，最后打开恢复进度对话框监听导入流。
  Future<void> handleRestoreBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showDialog<RestoreBackupSource>(
      context: context,
      builder: (context) => const RestoreSourceDialog(),
    );

    // User cancelled the source chooser — exit silently.
    if (source == null || !context.mounted) return;

    isSelectingFiles = true;
    try {
      final importService = ref.read(unifiedImportServiceProvider);
      final BackupPaths paths;
      Directory? cleanupDir;

      if (source == RestoreBackupSource.zipFile) {
        final picked = await importService.pickBackupZipFile();
        if (picked == null || !context.mounted) return;

        paths = await importService.processBackupZip(picked);
        // processBackupZip 的 rootPath 即导入缓存区内的解压目录。
        cleanupDir = Directory((paths.rootPath as IOSFilePath).path);
      } else {
        final picked = await importService.pickBackupFolder();
        if (picked == null || !context.mounted) return;
        paths = picked;
      }

      if (!context.mounted) return;

      // 2. Start the stream before opening the dialog so that no work is
      //    duplicated on dialog rebuilds.
      final progressStream = ref
          .read(libraryProvider.notifier)
          .importLibraryFromFolder(paths, cleanupDir: cleanupDir);

      // 3. Show the restore dialog; it subscribes to the stream and returns
      //    the final ImportResult when the user closes it.
      await showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Theme.of(
          context,
        ).colorScheme.scrim.withValues(alpha: 0.5),
        builder: (ctx) =>
            RestoreProgressDialog(stream: progressStream, l10n: l10n),
      );
    } on BackupArchiveViolationException {
      // 桥接 core 的归档校验异常到 library 错误码（zip bomb / 路径越界）。
      if (context.mounted) {
        ToastService.showError(
          libraryErrorMessage(
            AppLocalizations.of(context)!,
            LibraryErrorCode.backupArchiveInvalid,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ToastService.showError(
          libraryErrorMessageFor(l10n, e, fallback: l10n.restoreFailed),
        );
      }
    } finally {
      isSelectingFiles = false;
    }

    // 4. Refresh the library shelf after a successful restore.
    if (context.mounted) {
      await ref.read(bookshelfProvider.notifier).refresh();
    }
  }

  Future<String?> promptForGroupName(BuildContext context) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => const GroupNamePromptDialog(),
    );
    return (result?.trim().isNotEmpty ?? false) ? result : null;
  }
}
