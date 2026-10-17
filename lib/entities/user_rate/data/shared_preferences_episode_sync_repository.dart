import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/episode_sync_repository.dart';
import 'package:iris/shared/storage/json_list_preference.dart';
import 'package:iris/shared/utils/json_read.dart';

class SharedPreferencesEpisodeSyncRepository implements EpisodeSyncRepository {
  SharedPreferencesEpisodeSyncRepository(SharedPreferences preferences)
    : _preference = JsonListPreference(
        preferences,
        'pending_episode_marks',
        decode: _decode,
        encode: _encode,
        logName: 'EpisodeSync',
        corruptedMessage: 'Stored episode marks are invalid.',
      );

  final JsonListPreference<EpisodeSyncEntry> _preference;

  @override
  List<EpisodeSyncEntry> read() => _preference.read();

  @override
  Future<void> write(List<EpisodeSyncEntry> entries) =>
      _preference.write(entries);

  static EpisodeSyncEntry? _decode(Object? value) {
    if (value is! Map) return null;
    final json = jsonMap(value);
    final userId = jsonString(json['userId']);
    final animeId = jsonString(json['animeId']);
    if (userId.isEmpty || animeId.isEmpty) return null;
    final rawEpisodes = json['episodes'];
    final episodes = <int>{
      if (rawEpisodes is List)
        for (final value in rawEpisodes)
          if (value is int && value >= 1 && value <= 9999) value,
    };
    final rate = UserRateDto.tryParse(json['rate'])?.toEntity();
    return EpisodeSyncEntry(
      userId: userId,
      animeId: animeId,
      rateKnown:
          json['rateKnown'] == true && (json['rate'] == null || rate != null),
      rate: rate,
      episodes: List.unmodifiable(episodes),
      blocked: json['blocked'] == true,
    );
  }

  static Map<String, Object?> _encode(EpisodeSyncEntry entry) {
    final rate = entry.rate;
    return {
      'userId': entry.userId,
      'animeId': entry.animeId,
      'rateKnown': entry.rateKnown,
      'rate': rate == null
          ? null
          : {
              'id': rate.id,
              'status': UserRateDto.statusToApi(rate.status),
              'episodes': rate.episodes,
              'score': rate.score,
              if (rate.rewatches != null) 'rewatches': rate.rewatches,
            },
      'episodes': entry.episodes,
      if (entry.blocked) 'blocked': true,
    };
  }
}
