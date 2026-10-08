import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_track_preferences_repository.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

class SharedPreferencesTrackPreferencesRepository
    implements PlayerTrackPreferencesRepository {
  const SharedPreferencesTrackPreferencesRepository(this._preferences);

  static const _keyPrefix = 'player.track_preferences.';

  final SharedPreferences _preferences;

  @override
  Future<PlayerTrackPreferences?> load({required String torrentKey}) async {
    final raw =
        _preferences.getString('$_keyPrefix$torrentKey') ??
        _legacyEntry(torrentKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final preferences = PlayerTrackPreferences(
        audio: _trackFromJson(json['audio']),
        subtitle: _trackFromJson(json['subtitle']),
      );
      return preferences.isEmpty ? null : preferences;
    } on FormatException catch (error) {
      developer.log(
        'Ignoring corrupted track preferences for $torrentKey.',
        name: 'iris.player.track_preferences',
        error: error,
      );
      return null;
    }
  }

  /// A choice saved under the base32 key of the same torrent, before keys
  /// were unified to hex.
  String? _legacyEntry(String torrentKey) {
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith(_keyPrefix)) continue;
      final storedKey = key.substring(_keyPrefix.length);
      if (storedKey != torrentKey &&
          canonicalTorrentKey(storedKey) == torrentKey) {
        return _preferences.getString(key);
      }
    }
    return null;
  }

  @override
  Future<void> save({
    required String torrentKey,
    required PlayerTrackPreferences preferences,
  }) async {
    await _preferences.setString(
      '$_keyPrefix$torrentKey',
      jsonEncode({
        'audio': _trackToJson(preferences.audio),
        'subtitle': _trackToJson(preferences.subtitle),
      }),
    );
  }
}

Map<String, Object?>? _trackToJson(PreferredTrack? track) {
  if (track == null) return null;
  return {
    'language': track.language,
    'title': track.title,
    'disabled': track.disabled,
  };
}

PreferredTrack? _trackFromJson(Object? json) {
  if (json is! Map) return null;
  final language = json['language'];
  final title = json['title'];
  return PreferredTrack(
    language: language is String ? language : null,
    title: title is String ? title : null,
    disabled: json['disabled'] == true,
  );
}
