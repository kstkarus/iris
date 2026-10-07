import 'package:flutter/material.dart';

/// The app's theme in the opposite brightness, carried by each theme for
/// surfaces that sit on top of a page: sheets, dialogs and menus are set in
/// reverse, bone over an ink page and ink over a bone one.
class InverseTheme extends ThemeExtension<InverseTheme> {
  const InverseTheme(this.theme);

  final ThemeData theme;

  /// The twin of [base], or [base] itself when it carries none.
  static ThemeData of(ThemeData base) =>
      base.extension<InverseTheme>()?.theme ?? base;

  @override
  InverseTheme copyWith({ThemeData? theme}) =>
      InverseTheme(theme ?? this.theme);

  @override
  InverseTheme lerp(InverseTheme? other, double t) =>
      t < 0.5 || other == null ? this : other;
}
