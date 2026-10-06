import 'dart:developer' as developer;

import 'package:iris/features/player/data/mappers/aniskip_skip_time_mapper.dart';
import 'package:iris/features/player/data/models/aniskip_skip_time_dto.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/repositories/player_skip_times_repository.dart';
import 'package:iris/shared/network/aniskip_api_client.dart';

class AniSkipSkipTimesRepository implements PlayerSkipTimesRepository {
  const AniSkipSkipTimesRepository({required AniSkipApiClient client})
    : _client = client;

  final AniSkipApiClient _client;

  @override
  Future<List<PlayerSkipSegment>> find({
    required String animeId,
    required int episode,
    required Duration duration,
  }) async {
    if (int.tryParse(animeId) == null ||
        episode <= 0 ||
        duration <= Duration.zero) {
      return const [];
    }
    try {
      final payload = await _client.fetchSkipTimes(
        malId: animeId,
        episode: episode,
        episodeLength: duration.inMilliseconds / 1000,
      );
      final results = payload['results'];
      if (payload['found'] != true || results is! List) return const [];
      return results
          .whereType<Map<String, dynamic>>()
          .map(AniSkipSkipTimeDto.fromJson)
          .map(mapAniSkipSkipTime)
          .nonNulls
          .toList();
    } catch (error, stackTrace) {
      // Skip times are optional; playback goes on without them.
      developer.log(
        'Unable to load skip times. animeId=$animeId episode=$episode',
        name: 'iris.player.skip',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }
}
