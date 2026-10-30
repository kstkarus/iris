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

/// Article parts of one anime form a release per translation. Players are
/// mirrors within that translation, with Kodik as a fallback.
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
    final found = await searchAll<String, _ArticleEpisodes>(
      {
        for (final title in titles)
          if (title.trim().isNotEmpty) title.trim(),
      },
      (title) async {
        final parts = <_ArticleEpisodes>[];
        Object? failure;
        try {
          await for (final candidates in dataSource.searchPages(title)) {
            try {
              final matching = await searchAll(
                candidates.where((id) => id > 0).toSet(),
                (id) async => [await (articles[id] ??= dataSource.article(id))],
                keep: (article) => article.shikimoriId == wanted,
              );
              parts.addAll(
                await searchAll(
                  matching,
                  (article) async => [
                    (
                      id: article.id,
                      episodes: await (playlists[article.id] ??= dataSource
                          .episodes(article.id)),
                    ),
                  ],
                  keep: (part) => part.episodes.isNotEmpty,
                ),
              );
            } on Object catch (error) {
              failure ??= error;
            }
          }
        } on Object catch (error) {
          failure ??= error;
        }
        if (parts.isEmpty && failure != null) throw failure;
        return parts;
      },
      keep: (part) => part.episodes.isNotEmpty,
    );
    final groups = <String, Map<int, List<AnimejoyEpisodeDto>>>{};
    for (final part in {for (final part in found) part.id: part}.values) {
      for (final episode in part.episodes) {
        final group = groups[_episodeTranslationKey(episode)] ??= {};
        (group[part.id] ??= []).add(episode);
      }
    }
    return [
      for (final group in groups.entries)
        _release(group.value, translation: group.key),
    ];
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    final parsed = _parseReleaseId(id);
    if (parsed == null) {
      throw ResourceNotFoundException('No AnimeJoy release $id.');
    }
    final parts = await searchAll<int, _ArticleEpisodes>(parsed.articles, (
      articleId,
    ) async {
      final episodes = await dataSource.episodes(articleId);
      // Old numeric links keep the article's first translation.
      final translation =
          parsed.translation ??
          (episodes.any((episode) => _episodeTranslationKey(episode).isEmpty)
              ? ''
              : episodes.isEmpty
              ? ''
              : _episodeTranslationKey(episodes.first));
      return [
        (
          id: articleId,
          episodes: episodes
              .where(
                (episode) => _episodeTranslationKey(episode) == translation,
              )
              .toList(growable: false),
        ),
      ];
    }, keep: (part) => part.episodes.isNotEmpty);
    if (parts.isEmpty) {
      throw ResourceNotFoundException('No playable AnimeJoy release $id.');
    }
    return _release(
      {for (final part in parts) part.id: part.episodes},
      translation:
          parsed.translation ??
          _episodeTranslationKey(parts.first.episodes.first),
      id: id,
    );
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    final parts = episodeId.split(':');
    final validParts = parts.length == 2 || parts.length == 3;
    final articleId = validParts ? int.tryParse(parts.first) : null;
    final number = validParts ? num.tryParse(parts[1]) : null;
    final translation = parts.length == 3 ? _decodeTranslation(parts[2]) : null;
    if (articleId == null ||
        articleId <= 0 ||
        number == null ||
        !number.isFinite ||
        number < 0 ||
        (parts.length == 3 && translation == null)) {
      throw ResourceNotFoundException('No AnimeJoy episode $episodeId.');
    }
    AnimejoyEpisodeDto? selectEpisode(List<AnimejoyEpisodeDto> episodes) {
      final candidates = episodes.where(
        (item) =>
            item.number == number &&
            (translation == null ||
                _episodeTranslationKey(item) == translation),
      );
      return translation == null
          ? candidates
                    .where((item) => _episodeTranslationKey(item).isEmpty)
                    .firstOrNull ??
                candidates.firstOrNull
          : candidates.firstOrNull;
    }

    // Ask the preferred players before loading either fallback catalog.
    var episode = selectEpisode(
      await dataSource.episodes(
        articleId,
        includeKodik: false,
        includeAlloha: false,
      ),
    );
    final streams = <OnlineStream>[];
    Object? firstError;
    final attempted = <String>{};
    Future<void> readPreferred(AnimejoyEpisodeDto? selected) async {
      if (selected == null) return;
      for (final url in selected.playerUrls) {
        if (!attempted.add(url)) continue;
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
    }

    await readPreferred(episode);
    if (streams.isEmpty) {
      try {
        episode = selectEpisode(
          await dataSource.episodes(articleId, includeKodik: false),
        );
        await readPreferred(episode);
        final fallback = episode?.alloha;
        if (streams.isEmpty && fallback != null) {
          final links = await dataSource.allohaLinks(
            url: fallback.url,
            videoId: fallback.videoId,
          );
          streams.addAll(links.map(mapVideoLink));
        }
      } on Object catch (error) {
        firstError ??= error;
      }
    }
    if (streams.isEmpty) {
      try {
        episode = selectEpisode(await dataSource.episodes(articleId));
        await readPreferred(episode);
        final fallback = episode?.kodik;
        if (streams.isEmpty && fallback != null) {
          try {
            final links = await dataSource.kodikLinks(
              url: fallback.url,
              videoId: fallback.videoId,
            );
            streams.addAll(links.map(mapVideoLink));
          } on Object catch (error) {
            firstError ??= error;
          }
        }
      } on Object catch (error) {
        firstError ??= error;
      }
    }
    if (episode == null && firstError == null) {
      throw ResourceNotFoundException('No AnimeJoy episode $episodeId.');
    }
    if (streams.isEmpty && firstError != null) throw firstError!;
    // List.sort is not stable; preserve the preferred mirror at a tie.
    final ordered = streams.indexed.toList()
      ..sort((a, b) {
        final quality = b.$2.quality.compareTo(a.$2.quality);
        return quality == 0 ? a.$1.compareTo(b.$1) : quality;
      });
    return ordered.map((entry) => entry.$2).toSet().toList(growable: false);
  }

  OnlineRelease _release(
    Map<int, List<AnimejoyEpisodeDto>> articles, {
    required String translation,
    String? id,
  }) {
    final articleIds = articles.keys.toList()..sort();
    final episodes = <num, ({int articleId, AnimejoyEpisodeDto episode})>{};
    // Prefer the newer article when ranges overlap; progress still uses
    // the original episode number, independently of the chosen article.
    for (final articleId in articleIds.reversed) {
      for (final episode in articles[articleId]!) {
        episodes.putIfAbsent(
          episode.number,
          () => (articleId: articleId, episode: episode),
        );
      }
    }
    final numbers = episodes.keys.toList()..sort();
    final name = episodes[numbers.first]!.episode.translation;
    var bestQuality = 0;
    for (final item in episodes.values) {
      final quality = item.episode.bestQuality ?? 0;
      if (quality > bestQuality) bestQuality = quality;
    }
    return OnlineRelease(
      provider: OnlineProvider.animejoy,
      id:
          id ??
          (articleIds.length == 1 && translation.isEmpty
              ? '${articleIds.single}'
              : 'parts:${articleIds.join(',')}:${Uri.encodeComponent(translation)}'),
      dub: name.isEmpty ? 'AnimeJoy' : 'AnimeJoy · $name',
      bestQuality: bestQuality > 0 ? bestQuality : null,
      episodes: [
        for (final number in numbers)
          OnlineEpisode(
            id: [
              '${episodes[number]!.articleId}:${_number(number)}',
              if (translation.isNotEmpty) Uri.encodeComponent(translation),
            ].join(':'),
            number: number,
            title: episodes[number]!.episode.title,
          ),
      ],
    );
  }
}

typedef _ArticleEpisodes = ({int id, List<AnimejoyEpisodeDto> episodes});

({List<int> articles, String? translation})? _parseReleaseId(String id) {
  final legacy = int.tryParse(id);
  if (legacy != null && legacy > 0) {
    return (articles: [legacy], translation: null);
  }
  final parts = id.split(':');
  if (parts.length != 3 || parts.first != 'parts') return null;
  final articles = <int>{};
  for (final value in parts[1].split(',')) {
    final article = RegExp(r'^\d+$').hasMatch(value)
        ? int.tryParse(value)
        : null;
    if (article == null || article <= 0) return null;
    articles.add(article);
  }
  final translation = _decodeTranslation(parts[2]);
  if (translation == null) return null;
  return (articles: articles.toList()..sort(), translation: translation);
}

String _translationKey(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _episodeTranslationKey(AnimejoyEpisodeDto episode) =>
    episode.translationKey ?? _translationKey(episode.translation);

String? _decodeTranslation(String value) {
  try {
    return _translationKey(Uri.decodeComponent(value));
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

String _number(num value) => value % 1 == 0 ? '${value.toInt()}' : '$value';
