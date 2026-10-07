import 'package:flutter/material.dart';

/// The app's dark theme, carried by the light one for surfaces that sit on
/// video: a player over a black frame stays dark whatever the system
/// brightness, and its dialogs keep the app's own look.
class OverVideoTheme extends ThemeExtension<OverVideoTheme> {
  const OverVideoTheme(this.theme);

  final ThemeData theme;

  /// [base] itself when it is dark already; a plain dark theme from its
  /// primary colour when it carries no dark twin.
  static ThemeData of(ThemeData base) {
    if (base.brightness == Brightness.dark) return base;
    return base.extension<OverVideoTheme>()?.theme ??
        ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: base.colorScheme.primary,
            brightness: Brightness.dark,
          ),
          visualDensity: base.visualDensity,
        );
  }

  @override
  OverVideoTheme copyWith({ThemeData? theme}) =>
      OverVideoTheme(theme ?? this.theme);

  @override
  OverVideoTheme lerp(OverVideoTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;
}
