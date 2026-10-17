import 'dart:developer' as developer;

import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/mappers/video_link_mapper.dart';
import 'package:iris/features/online_sources/data/models/animejoy_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/search_all.dart';

/// One release per AnimeJoy article. Its two players are mirrors of an
/// episode, not separate translations.
class AnimejoyOnlineSourcesRepository implements OnlineSourcesRepository {
  const AnimejoyOnlineSourcesRepository({required this.dataSource});

  final AnimejoyDataSource dataSource;

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    final wanted = int.tryParse(shikimoriId);
    if (wanted == null || wanted <= 0) return const [];
    // Several names can find the same article. Share only this search's
    // requests; a later search or playback must see the current playlist.
    final articles = <int, Future<AnimejoyArticleDto>>{};
    final playlists = <int, Future<List<AnimejoyEpisodeDto>>>{};
    final found = await searchAll(
      {
        for (final title in titles)
          if (title.trim().isNotEmpty) title.trim(),
      },
      (title) async {
        final candidates = await dataSource.search(title);
        final matching = await searchAll(
          candidates.where((id) => id > 0).toSet(),
          (id) async => [await (articles[id] ??= dataSource.article(id))],
          keep: (article) => article.shikimoriId == wanted,
        );
        return searchAll(
          matching,
          (article) async => [
            _release(
              article.id,
              await (playlists[article.id] ??= dataSource.episodes(article.id)),
            ),
          ],
          keep: (release) => release.episodes.isNotEmpty,
        );
      },
      keep: (release) => release.episodes.isNotEmpty,
    );
    return found.toSet().toList(growable: false);
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    final articleId = int.tryParse(id);
    if (articleId == null || articleId <= 0) {
      throw ResourceNotFoundException('No AnimeJoy release $id.');
    }
    final episodes = await dataSource.episodes(articleId);
    if (episodes.isEmpty) {
      throw ResourceNotFoundException('No playable AnimeJoy release $id.');
    }
    return _release(articleId, episodes);
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    final parts = episodeId.split(':');
    final articleId = parts.length == 2 ? int.tryParse(parts.first) : null;
    final number = parts.length == 2 ? num.tryParse(parts.last) : null;
    if (articleId == null ||
        articleId <= 0 ||
        number == null ||
        !number.isFinite ||
        number < 0) {
      throw ResourceNotFoundException('No AnimeJoy episode $episodeId.');
    }
    // Re-read the playlist: expiring CDN links never become episode ids,
    // and an episode can gain another mirror or a higher quality later.
    final episodes = await dataSource.episodes(articleId);
    final episode = episodes.where((item) => item.number == number).firstOrNull;
    if (episode == null) {
      throw ResourceNotFoundException('No AnimeJoy episode $episodeId.');
    }
    final streams = <OnlineStream>[];
    Object? firstError;
    for (final url in episode.playerUrls) {
      try {
        final links = await dataSource.links(url);
        streams.addAll(links.map(mapVideoLink));
      } on Object catch (error) {
        firstError ??= error;
        developer.log(
          'An AnimeJoy player gave no links for episode $episodeId.',
          name: 'iris.online.animejoy',
          error: error,
        );
      }
    }
    if (streams.isEmpty && firstError != null) throw firstError;
    // List.sort is not stable; preserve the preferred mirror at a tie.
    final ordered = streams.indexed.toList()
      ..sort((a, b) {
        final quality = b.$2.quality.compareTo(a.$2.quality);
        return quality == 0 ? a.$1.compareTo(b.$1) : quality;
      });
    return ordered.map((entry) => entry.$2).toSet().toList(growable: false);
  }

  OnlineRelease _release(int articleId, List<AnimejoyEpisodeDto> episodes) {
    var bestQuality = 0;
    for (final episode in episodes) {
      final quality = episode.bestQuality ?? 0;
      if (quality > bestQuality) bestQuality = quality;
    }
    return OnlineRelease(
      provider: OnlineProvider.animejoy,
      id: '$articleId',
      dub: 'AnimeJoy',
      bestQuality: bestQuality > 0 ? bestQuality : null,
      episodes: [
        for (final episode in episodes)
          OnlineEpisode(
            id: '$articleId:${_number(episode.number)}',
            number: episode.number,
            title: episode.title,
          ),
      ],
    );
  }
}

String _number(num value) => value % 1 == 0 ? '${value.toInt()}' : '$value';
