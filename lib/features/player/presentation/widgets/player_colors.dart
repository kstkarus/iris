import 'package:flutter/material.dart';

/// The player's accent over video: the app's signal, which reads the same
/// on a dark frame in both themes.
Color playerAccentColor(ColorScheme scheme) => scheme.tertiaryFixed;

/// Shared surface, border and text tokens for floating plates over video.
const playerPlateBackground = Color(0xE60B0C0E);
const playerPlateBorder = Color(0xFF3A3D42);
const playerPlateActionBorder = Color(0xFF565A62);
const playerPlateText = Color(0xFFF2F2F0);
const playerPlateSecondary = Color(0xFFA8AAB0);
const playerPlateWarning = Color(0xFFFFD93B);
