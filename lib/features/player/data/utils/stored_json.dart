import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Reads the JSON object stored under [key] through [fromJson], or returns
/// [fallback] when nothing is stored or the record does not parse.
T readStoredJson<T>(
  SharedPreferences preferences,
  String key, {
  required T Function(Map<String, Object?> json) fromJson,
  required T fallback,
}) {
  final rawValue = preferences.getString(key);
  if (rawValue == null || rawValue.isEmpty) return fallback;

  try {
    final decoded = jsonDecode(rawValue);
    if (decoded is Map) {
      return fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
  } catch (_) {
    return fallback;
  }
  return fallback;
}

Future<void> writeStoredJson(
  SharedPreferences preferences,
  String key,
  Map<String, Object?> json,
) {
  return preferences.setString(key, jsonEncode(json));
}
