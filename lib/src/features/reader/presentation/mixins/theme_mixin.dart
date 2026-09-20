part of '../reader_screen.dart';

/// 将 Flutter 主题解析成排版参数，异步排版由阅读会话拥有。
mixin _ThemeMixin on ConsumerState<ReaderScreen> {
  ReaderWorkflow get workflow;
  ThemeData? get currentTheme;
  set currentTheme(ThemeData? value);
  void dismissWordPopup();

  EpubTheme getEpubTheme() =>
      ref.read(readerSettingsProvider).toEpubTheme(context);

  void handleSystemThemeChanged() {
    final theme = Theme.of(context);
    final previous = currentTheme;
    currentTheme = theme;
    if (previous != null && previous.colorScheme != theme.colorScheme) {
      updateWebViewThemeWithDebounce();
    }
  }

  void updateWebViewThemeWithDebounce() {
    dismissWordPopup();
    workflow.requestTheme(getEpubTheme(), debounce: true);
  }

  void updateWebViewTheme() {
    dismissWordPopup();
    workflow.requestTheme(getEpubTheme());
  }
}
