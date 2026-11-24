import 'dart:developer' as developer;

import 'package:iris/features/player/data/mappers/tenrai_episode_mapper.dart';
import 'package:iris/features/player/data/models/tenrai_episode_dto.dart';
import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/repositories/episode_metadata_repository.dart';
import 'package:iris/shared/network/tenrai_api_client.dart';
import 'package:iris/shared/utils/json_read.dart';

/// Fetches episode titles and filler/recap flags from Tenrai v1 and keeps them
/// for the session so the release page and the player drawer share one lookup.
class TenraiEpisodeMetadataRepository implements EpisodeMetadataRepository {
  TenraiEpisodeMetadataRepository({required TenraiApiClient client})
    : _client = client;

  static const _maxPages = 20;

  final TenraiApiClient _client;
  final _cache = <String, _CachedAnimeEpisodes>{};
  final _inFlight = <String, Future<Map<int, EpisodeMetadata>>>{};

  @override
  Future<Map<int, EpisodeMetadata>> findForAnime({
    required String animeId,
    int? upToEpisode,
  }) async {
    final id = int.tryParse(animeId);
    if (id == null || id <= 0) return const {};

    final key = '$id';
    final target = upToEpisode != null && upToEpisode > 0 ? upToEpisode : 1;

    final existing = _cache[key];
    if (existing != null && existing.satisfies(target)) {
      return existing.snapshot();
    }

    // Serialize fetches for the same anime so concurrent callers share work
    // without fetching the same page twice.
    while (true) {
      final pending = _inFlight[key];
      if (pending == null) break;
      await pending;
      final after = _cache[key];
      if (after != null && after.satisfies(target)) {
        return after.snapshot();
      }
    }

    final future = _loadUpTo(key, target);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    }
  }

  Future<Map<int, EpisodeMetadata>> _loadUpTo(
    String malId,
    int targetEpisode,
  ) async {
    final entry = _cache.putIfAbsent(malId, _CachedAnimeEpisodes.new);
    try {
      while (!entry.satisfies(targetEpisode) && entry.pagesLoaded < _maxPages) {
        final nextPage = entry.pagesLoaded + 1;
        final payload = await _client.fetchEpisodesPage(
          malId: malId,
          page: nextPage,
        );
        if (payload == null) {
          entry.hasNextPage = false;
          break;
        }

        final data = payload['data'];
        if (data is! List) {
          entry.hasNextPage = false;
          break;
        }

        var pageHighest = entry.highestEpisode;
        for (final item in data.whereType<Map<String, dynamic>>()) {
          final dto = TenraiEpisodeDto.fromJson(item);
          final number = dto.number;
          if (number != null && number > pageHighest) {
            pageHighest = number;
          }
          final mapped = mapTenraiEpisode(dto);
          if (mapped != null) {
            entry.episodes[mapped.number] = mapped;
          }
        }

        final pagination = jsonMap(payload['pagination']);
        final hasNext = pagination['has_next_page'] == true;
        entry
          ..pagesLoaded = nextPage
          ..highestEpisode = pageHighest
          ..hasNextPage = hasNext && data.isNotEmpty;
      }
    } on Object catch (error, stackTrace) {
      // Episode metadata is optional; keep whatever pages already arrived and
      // allow a later open to try again.
      developer.log(
        'Unable to load episode metadata. animeId=$malId',
        name: 'iris.player.episodes',
        error: error,
        stackTrace: stackTrace,
      );
      if (entry.pagesLoaded == 0) {
        _cache.remove(malId);
      }
    }
    return entry.snapshot();
  }
}

class _CachedAnimeEpisodes {
  final episodes = <int, EpisodeMetadata>{};
  int pagesLoaded = 0;
  int highestEpisode = 0;
  bool hasNextPage = true;

  bool satisfies(int targetEpisode) {
    if (pagesLoaded == 0) return !hasNextPage;
    return !hasNextPage || highestEpisode >= targetEpisode;
  }

  Map<int, EpisodeMetadata> snapshot() => Map.unmodifiable(episodes);
}
