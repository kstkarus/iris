import 'package:flutter/material.dart';

const _seedColor = Color(0xFF3D63FF);

/// Material 3 theme generated from a single seed color.
///
/// All surfaces and text colors come from the generated [ColorScheme], so the
/// light and dark variants stay consistent and a dynamic scheme can be
/// swapped in later without touching widgets.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(height: 1.5),
    ),
  );
}
