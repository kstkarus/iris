import 'dart:developer' as developer;

import 'package:iris/features/online_sources/data/datasources/aksor_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/kodik_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/yummy_anime_data_source.dart';
import 'package:iris/features/online_sources/data/mappers/yummy_anime_mapper.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/search_all.dart';

/// Follows anicli-api 0.12.0, `anicli_api/source/yummy_anime.py`, with its
/// Kodik and Aksor players. Each dub is a release of its own.
class YummyAnimeOnlineSourcesRepository implements OnlineSourcesRepository {
  const YummyAnimeOnlineSourcesRepository({
    required this.dataSource,
    required this.kodik,
    required this.aksor,
  });

  final YummyAnimeDataSource dataSource;
  final KodikDataSource kodik;
  final AksorDataSource aksor;

  /// One search per title, together; only anime yummy_anime links to the
  /// Shikimori id are kept. A failure is thrown only when nothing matched.
  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    final id = int.tryParse(shikimoriId);
    if (id == null) return const [];
    final queries = {
      for (final title in titles)
        if (title.trim().isNotEmpty) title.trim(),
    };
    final found = await searchAll(
      queries,
      dataSource.search,
      keep: (item) => item.shikimoriId == id && item.animeId != 0,
    );
    if (found.isEmpty) return const [];
    final matching = {for (final item in found) item.animeId: item};
    final releases = await Future.wait(
      matching.values.map(
        (anime) async => mapYummyReleases(
          animeId: anime.animeId,
          title: anime.title,
          videos: await dataSource.videos(anime.animeId),
        ),
      ),
    );
    return [for (final list in releases) ...list];
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    final parts = parseYummyReleaseId(id);
    if (parts == null) {
      throw ResourceNotFoundException('No yummy_anime release $id.');
    }
    final release = findYummyRelease(
      releaseId: id,
      videos: await dataSource.videos(parts.animeId),
    );
    if (release == null) {
      throw ResourceNotFoundException('No yummy_anime release $id.');
    }
    return release;
  }

  /// Every player of the episode is asked, the better first; one that
  /// fails leaves the others. The failure is thrown only when none
  /// answered.
  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    final streams = <OnlineStream>[];
    Object? firstError;
    for (final url in decodeYummyEpisodeId(episodeId)) {
      final player = YummyPlayer.of(url);
      if (player == null) continue;
      try {
        final links = await _links(player, url);
        streams.addAll(links.map(mapVideoLink));
      } on Object catch (error) {
        developer.log(
          '${player.name} gave no links for $url: $error',
          name: 'iris.online.yummy_anime',
        );
        firstError ??= error;
      }
    }
    if (streams.isEmpty && firstError != null) throw firstError;
    return streams;
  }

  Future<List<VideoLinkDto>> _links(YummyPlayer player, String url) {
    return switch (player) {
      YummyPlayer.aksor => aksor.links(url),
      YummyPlayer.kodik => kodik.links(url),
    };
  }
}
