import 'package:flutter/material.dart';
import 'package:synlen/src/core/theme/app_theme.dart';
import 'package:synlen/src/core/theme/color_schemes.dart';

/// ============================================================================
/// HOW TO ADD A NEW THEME VARIANT:
///
/// 1. Add the Light & Dark variants to the enums:
///    Update [AppThemeVariant]with your new theme name (e.g., `sakura`).
///
/// 2. Define the preset values in this enum:
///    Add the corresponding light and dark presets at the END of this enum.
///    WARNING: Do NOT reorder or remove existing values! The declaration order
///    is stable and defines the persisted integer [index] used by
///    [ReaderSettings.themeIndex].
///    Example:
///      sakuraLight(
///        colorSchemeGetter: kSakuraLightColorScheme,
///        shouldOverrideTextColor: true,
///        overridePrimaryColor: null,
///      ),
///
/// 3. Update mappings in [AppThemeSettings]:
///    Update the switch expressions in `_lightPresetFor()` and `_darkPresetFor()`
///    to map your new variants to your new presets.
/// ============================================================================

/// Determines which ThemeMode the app uses.
enum AppThemeMode { system, light, dark }

/// Selects one of the available color schemes.
enum AppThemeVariant {
  standard,
  eyeCare,
  matcha,
  midnight,
  sakura,
  ocean,
  twilight,
  coffee,
}

/// A single source of truth for every selectable theme in the app.
///
/// Enum declaration order is stable and defines the persisted [index] used by
/// [ReaderSettings.themeIndex] — never reorder or remove values.
enum SynlenThemePreset {
  // index 0
  standardLight(
    colorSchemeGetter: kLightColorScheme,
    shouldOverrideTextColor: false,
    overridePrimaryColor: null,
  ),
  // index 1
  standardDark(
    colorSchemeGetter: kDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: Color(0xFF7B9CAE),
  ),
  // index 2
  eyeCareLight(
    colorSchemeGetter: kEyeCareColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 3
  eyeCareDark(
    colorSchemeGetter: kDarkEyeCareColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 4
  matchaLight(
    colorSchemeGetter: kMatchaLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 5
  matchaDark(
    colorSchemeGetter: kMatchaDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 6
  midnightLight(
    colorSchemeGetter: kMidnightLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 7
  midnightDark(
    colorSchemeGetter: kMidnightDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 8
  sakuraLight(
    colorSchemeGetter: kSakuraLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 9
  sakuraDark(
    colorSchemeGetter: kSakuraDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 10
  oceanLight(
    colorSchemeGetter: kOceanLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 11
  oceanDark(
    colorSchemeGetter: kOceanDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 12
  twilightLight(
    colorSchemeGetter: kTwilightLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 13
  twilightDark(
    colorSchemeGetter: kTwilightDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 14
  coffeeLight(
    colorSchemeGetter: kCoffeeLightColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  ),
  // index 15
  coffeeDark(
    colorSchemeGetter: kCoffeeDarkColorScheme,
    shouldOverrideTextColor: true,
    overridePrimaryColor: null,
  );

  const SynlenThemePreset({
    required ColorScheme colorSchemeGetter,

    /// For reader themes only: whether to override the EPUB's default text color
    /// with the preset's text color.
    required this.shouldOverrideTextColor,

    /// For reader themes only: a single accent color to use in place of the EPUB's default
    /// accent color. This is necessary for themes like standardDark where the default accent
    /// color (black) would be unreadable against the dark background.
    required this.overridePrimaryColor,
  }) : colorScheme = colorSchemeGetter;

  final ColorScheme colorScheme;
  final bool shouldOverrideTextColor;
  final Color? overridePrimaryColor;

  /// Safely resolves a persisted integer back to a [SynlenThemePreset].
  /// Falls back to [standardLight] for out-of-range values.
  static SynlenThemePreset fromIndex(int index) {
    final values = SynlenThemePreset.values;
    if (index < 0 || index >= values.length) return standardLight;
    return values[index];
  }

  static List<SynlenThemePreset> get lightPresets => values
      .where((preset) => preset.colorScheme.brightness == Brightness.light)
      .toList();

  static List<SynlenThemePreset> get darkPresets => values
      .where((preset) => preset.colorScheme.brightness == Brightness.dark)
      .toList();
}

/// Persistent settings that control the app-wide color theme and
/// (optionally) the dark/light variant applied to library, detail and
/// about screens.
class AppThemeSettings {
  final AppThemeMode themeMode;
  final AppThemeVariant themeVariant;

  const AppThemeSettings({
    this.themeMode = AppThemeMode.system,
    this.themeVariant = AppThemeVariant.standard,
  });

  AppThemeSettings copyWith({
    AppThemeMode? themeMode,
    AppThemeVariant? themeVariant,
  }) {
    return AppThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      themeVariant: themeVariant ?? this.themeVariant,
    );
  }

  /// Maps to Flutter's [ThemeMode] for use in [MaterialApp].
  ThemeMode get flutterThemeMode => switch (themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// The active light preset based on the current variant.
  SynlenThemePreset get activeLightPreset => _lightPresetFor(themeVariant);

  /// The active dark preset based on the current variant.
  SynlenThemePreset get activeDarkPreset => _darkPresetFor(themeVariant);

  /// The [ColorScheme] used when the app is in light mode.
  ColorScheme get lightColorScheme => activeLightPreset.colorScheme;

  /// The [ColorScheme] used when the app is in dark mode.
  ColorScheme get darkColorScheme => activeDarkPreset.colorScheme;

  /// [ThemeData] built from the chosen light scheme, with [SynlenThemeExtension] injected.
  ThemeData get lightTheme => AppTheme.buildTheme(
    lightColorScheme,
  ).copyWith(extensions: [SynlenThemeExtension(preset: activeLightPreset)]);

  /// [ThemeData] built from the chosen dark scheme, with [SynlenThemeExtension] injected.
  ThemeData get darkTheme => AppTheme.buildTheme(
    darkColorScheme,
  ).copyWith(extensions: [SynlenThemeExtension(preset: activeDarkPreset)]);

  /// Returns the color scheme that is actually active at runtime, given the
  /// current [platformBrightness].
  ColorScheme resolvedColorScheme(Brightness platformBrightness) {
    final effectiveBrightness = switch (themeMode) {
      AppThemeMode.system => platformBrightness,
      AppThemeMode.light => Brightness.light,
      AppThemeMode.dark => Brightness.dark,
    };
    return effectiveBrightness == Brightness.dark
        ? darkColorScheme
        : lightColorScheme;
  }

  /// Maps a [AppThemeVariant] to its corresponding [ColorScheme] based on the given brightness.
  static ColorScheme colorSchemeFor(
    AppThemeVariant variant,
    Brightness brightness,
  ) => brightness == Brightness.dark
      ? _darkPresetFor(variant).colorScheme
      : _lightPresetFor(variant).colorScheme;

  /// Maps a [AppThemeVariant] to its [SynlenThemePreset].
  static SynlenThemePreset _lightPresetFor(AppThemeVariant variant) =>
      switch (variant) {
        AppThemeVariant.standard => SynlenThemePreset.standardLight,
        AppThemeVariant.eyeCare => SynlenThemePreset.eyeCareLight,
        AppThemeVariant.matcha => SynlenThemePreset.matchaLight,
        AppThemeVariant.midnight => SynlenThemePreset.midnightLight,
        AppThemeVariant.sakura => SynlenThemePreset.sakuraLight,
        AppThemeVariant.ocean => SynlenThemePreset.oceanLight,
        AppThemeVariant.twilight => SynlenThemePreset.twilightLight,
        AppThemeVariant.coffee => SynlenThemePreset.coffeeLight,
      };

  /// Maps a [AppThemeVariant] to its [SynlenThemePreset].
  static SynlenThemePreset _darkPresetFor(AppThemeVariant variant) =>
      switch (variant) {
        AppThemeVariant.standard => SynlenThemePreset.standardDark,
        AppThemeVariant.eyeCare => SynlenThemePreset.eyeCareDark,
        AppThemeVariant.matcha => SynlenThemePreset.matchaDark,
        AppThemeVariant.midnight => SynlenThemePreset.midnightDark,
        AppThemeVariant.sakura => SynlenThemePreset.sakuraDark,
        AppThemeVariant.ocean => SynlenThemePreset.oceanDark,
        AppThemeVariant.twilight => SynlenThemePreset.twilightDark,
        AppThemeVariant.coffee => SynlenThemePreset.coffeeDark,
      };

  /// Maps a [AppThemeVariant] to its [SynlenThemePreset].
  static SynlenThemePreset presetFor(
    AppThemeVariant variant,
    Brightness brightness,
  ) {
    return brightness == Brightness.dark
        ? _darkPresetFor(variant)
        : _lightPresetFor(variant);
  }
}

/// A [ThemeExtension] that injects the active [SynlenThemePreset] into the
/// widget tree, making it accessible via [Theme.of(context).extension<SynlenThemeExtension>()].
class SynlenThemeExtension extends ThemeExtension<SynlenThemeExtension> {
  const SynlenThemeExtension({required this.preset});

  final SynlenThemePreset preset;

  @override
  SynlenThemeExtension copyWith({SynlenThemePreset? preset}) =>
      SynlenThemeExtension(preset: preset ?? this.preset);

  /// Enums cannot be meaningfully interpolated, so snap at the midpoint.
  @override
  SynlenThemeExtension lerp(covariant SynlenThemeExtension? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

