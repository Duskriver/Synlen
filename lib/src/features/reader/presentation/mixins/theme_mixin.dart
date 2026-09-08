part of '../reader_screen.dart';

mixin _ThemeMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  ReaderRendererController get rendererController;

  ThemeData? get currentTheme;
  set currentTheme(ThemeData? v);

  ReaderNavigator get navigator;

  Timer? get themeUpdateDebouncer;
  set themeUpdateDebouncer(Timer? v);

  void saveProgressDebounced();

  EpubTheme getEpubTheme() {
    final settings = ref.read(readerSettingsProvider);
    return settings.toEpubTheme(context);
  }

  /// 依赖变化时跟踪系统主题：首次记录，之后变化则防抖刷新 WebView 主题。
  void handleSystemThemeChanged() {
    final systemTheme = Theme.of(context);
    if (currentTheme == null) {
      currentTheme = systemTheme;
    } else if (currentTheme?.colorScheme != systemTheme.colorScheme) {
      currentTheme = systemTheme;
      updateWebViewThemeWithDebounce();
    }
  }

  void updateWebViewThemeWithDebounce() {
    themeUpdateDebouncer?.cancel();
    // 增加防抖时间，减少 WebView 主线程压力
    themeUpdateDebouncer = Timer(const Duration(milliseconds: 200), () {
      updateWebViewTheme();
    });
  }

  Future<void> updateWebViewTheme() async {
    if (!mounted) {
      return;
    }

    final newTheme = getEpubTheme();
    final currentTheme = rendererController.currentTheme;
    if (currentTheme != null && currentTheme == newTheme) {
      return;
    }

    navigator.beginThemeRefresh();

    await rendererController.updateTheme(getEpubTheme());

    if (!mounted) {
      return;
    }

    navigator.endThemeRefresh();
    saveProgressDebounced();
  }
}
