import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seedColor = Color(0xFF3D63FF);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFF111827),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: Color(0xFF4B5563)),
    ),
  );
}
