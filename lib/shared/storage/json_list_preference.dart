import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// A list kept as one JSON array under [key]. Entries that do not decode are
/// skipped; storage that is not JSON reads as an empty list and is logged
/// with [corruptedMessage].
class JsonListPreference<T> {
  const JsonListPreference(
    this._preferences,
    this.key, {
    required T? Function(Object? json) decode,
    required Map<String, Object?> Function(T item) encode,
    required this.logName,
    required this.corruptedMessage,
  }) : _decode = decode,
       _encode = encode;

  final SharedPreferences _preferences;
  final String key;
  final T? Function(Object? json) _decode;
  final Map<String, Object?> Function(T item) _encode;
  final String logName;
  final String corruptedMessage;

  List<T> read() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [for (final entry in decoded) ?_decode(entry)];
    } on FormatException catch (error, stackTrace) {
      developer.log(
        corruptedMessage,
        name: logName,
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> write(List<T> items) async {
    await _preferences.setString(
      key,
      jsonEncode([for (final item in items) _encode(item)]),
    );
  }
}
