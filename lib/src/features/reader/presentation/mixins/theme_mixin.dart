part of '../reader_screen.dart';

mixin _ThemeMixin on ConsumerState<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  ReaderRendererController get rendererController;

  ThemeData? get currentTheme;
  set currentTheme(ThemeData? v);

  bool get updatingTheme;
  set updatingTheme(bool v);

  Timer? get themeUpdateDebouncer;
  set themeUpdateDebouncer(Timer? v);

  void saveProgressDebounced();

  EpubTheme getEpubTheme() {
    final settings = ref.read(readerSettingsProvider);
    return settings.toEpubTheme(context);
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

    setState(() {
      updatingTheme = true;
    });

    await rendererController.updateTheme(getEpubTheme());

    if (!mounted) {
      return;
    }

    setState(() {
      updatingTheme = false;
    });
    saveProgressDebounced();
  }
}
