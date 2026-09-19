part of '../reader_screen.dart';

mixin _LinkHandlingMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  BookSession get bookSession;

  ReaderWorkflow get workflow;

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  bool shouldHandleLinkTap(String url) {
    final settings = ref.read(readerSettingsProvider);
    if (url.startsWith('book://')) {
      if (!settings.handleIntraLink) return false;
      final index = bookSession.findSpineIndexByUrl(url);
      return index != null;
    } else {
      return settings.linkHandling != ReaderLinkHandling.never;
    }
  }

  Future<void> handleLinkTap(String url) async {
    if (url.startsWith('book://')) {
      await workflow.followInternalLink(url);
    } else {
      final linkHandling = ref.read(readerSettingsProvider).linkHandling;

      final uri = Uri.tryParse(url);

      if (uri != null && await UrlLauncher.canLaunch(uri)) {
        if (linkHandling == ReaderLinkHandling.always) {
          await UrlLauncher.launch(uri);
        } else if (linkHandling == ReaderLinkHandling.ask) {
          if (mounted && context.mounted) {
            final themeData = getEpubTheme().themeData;
            final shouldOpen =
                await showDialog<bool>(
                  context: context,
                  builder: (context) => Theme(
                    data: themeData,
                    child: AlertDialog(
                      title: Text(
                        AppLocalizations.of(context)!.openExternalLink,
                      ),
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.openExternalLinkConfirmation(url),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(AppLocalizations.of(context)!.open),
                        ),
                      ],
                    ),
                  ),
                ) ??
                false;

            if (shouldOpen) {
              await UrlLauncher.launch(uri);
            }
          }
        }
        // ReaderLinkHandling.never: do nothing
      } else {
        if (mounted && context.mounted) {
          ToastService.showError(
            AppLocalizations.of(context)!.cannotOpenLink(url),
            theme: getEpubTheme().themeData,
          );
        }
      }
    }
  }
}
