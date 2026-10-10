import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The tokens Shikimori issued for the signed-in account.
class ShikimoriTokens {
  const ShikimoriTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory ShikimoriTokens.fromJson(Map<String, dynamic> json) =>
      ShikimoriTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

/// Keeps the Shikimori session in the platform's secure storage and in
/// memory, so requests do not wait on the keychain each time.
class ShikimoriSessionStore {
  ShikimoriSessionStore(this._storage);

  static const _storageKey = 'shikimori.session';

  final FlutterSecureStorage _storage;
  final _expired = StreamController<void>.broadcast();

  ShikimoriTokens? _tokens;
  bool _loaded = false;

  /// Fires when Shikimori no longer accepts the session (see [expire]); a
  /// sign-out the user asked for does not.
  Stream<void> get expired => _expired.stream;

  Future<ShikimoriTokens?> read() async {
    if (_loaded) return _tokens;
    String? value;
    try {
      value = await _storage.read(key: _storageKey);
    } catch (_) {
      // A keystore that cannot be read is a signed-out app, not a crash.
    }
    _tokens = _decode(value);
    _loaded = true;
    return _tokens;
  }

  Future<void> write(ShikimoriTokens tokens) async {
    _tokens = tokens;
    _loaded = true;
    await _storage.write(key: _storageKey, value: jsonEncode(tokens.toJson()));
  }

  Future<void> clear() async {
    _tokens = null;
    _loaded = true;
    await _storage.delete(key: _storageKey);
  }

  /// Drops a session Shikimori refused to renew and tells whoever shows it.
  Future<void> expire() async {
    await clear();
    _expired.add(null);
  }

  static ShikimoriTokens? _decode(String? value) {
    if (value == null) return null;
    try {
      return ShikimoriTokens.fromJson(
        jsonDecode(value) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
