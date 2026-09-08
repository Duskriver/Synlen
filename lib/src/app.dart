import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:synlen/src/core/config/app_info.dart';
import 'package:synlen/src/core/theme/app_theme_notifier.dart';
import 'package:synlen/src/global_share_handler.dart';
import '../l10n/app_localizations.dart';
import 'app_router.dart';

/// 系统语言 Provider，确保只在初始化或真正变化时触发更新
final localeProvider = Provider<Locale>((ref) {
  final systemLocale = Platform.localeName;
  return Locale(systemLocale.split('_')[0]);
});

/// Root application widget
class SynlenReaderApp extends ConsumerWidget {
  const SynlenReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appTheme = ref.watch(appThemeProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppInfo.appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: _NoOverscrollBehavior(),

      // Localization
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('zh'), // Chinese
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          for (var locale in supportedLocales) {
            if (locale.languageCode == deviceLocale.languageCode) {
              return locale;
            }
          }
        }
        return const Locale('en'); // Fallback to English
      },

      // Modern Minimalist Theme
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: appTheme.flutterThemeMode,

      // Navigation
      routerConfig: router,
      builder: (context, child) =>
          GlobalShareHandler(child: child ?? const SizedBox.shrink()),
    );
  }
}

class _NoOverscrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
