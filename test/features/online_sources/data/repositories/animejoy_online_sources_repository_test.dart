import 'package:flutter_test/flutter_test.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/models/animejoy_dto.dart';
import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';

void main() {
  const target = 52991;

  test(
    'keeps only exact Shikimori matches and makes one article release',
    () async {
      final source = _FakeAnimejoyDataSource(
        searchResults: {
          'Frieren': [10, 11, 12],
        },
        articles: {
          10: const AnimejoyArticleDto(id: 10, shikimoriId: target),
          11: const AnimejoyArticleDto(id: 11, shikimoriId: 999),
          12: const AnimejoyArticleDto(id: 12),
        },
        playlists: {
          10: [
            _episode(
              1,
              urls: [
                'https://animejoy.ru/player/1',
                'https://allvideo.example/1',
              ],
            ),
            _episode(1.5, title: 'Special'),
          ],
        },
      );

      final releases = await _repository(
        source,
      ).findReleases(shikimoriId: '$target', titles: const ['Frieren']);

      expect(releases, hasLength(1));
      expect(releases.single.provider, OnlineProvider.animejoy);
      expect(releases.single.id, '10');
      expect(releases.single.dub, 'AnimeJoy');
      expect(
        [for (final episode in releases.single.episodes) episode.id],
        ['10:1', '10:1.5'],
      );
      expect(releases.single.episodes.last.title, 'Special');
      expect(source.articleCalls, unorderedEquals([10, 11, 12]));
      expect(source.playlistCalls, [10]);
    },
  );

  test('trims and deduplicates queries and candidate article ids', () async {
    final source = _FakeAnimejoyDataSource(
      searchResults: {
        'A': [20, 20],
        'B': [20],
      },
      articles: {20: const AnimejoyArticleDto(id: 20, shikimoriId: target)},
      playlists: {
        20: [_episode(1)],
      },
    );

    await _repository(
      source,
    ).findReleases(shikimoriId: '$target', titles: const [' A ', 'A', '', 'B']);

    expect(source.searchCalls, unorderedEquals(['A', 'B']));
    expect(source.articleCalls, [20]);
    expect(source.playlistCalls, [20]);
  });

  test(
    'query, article, or playlist failures do not hide a good release',
    () async {
      final source = _FakeAnimejoyDataSource(
        searchResults: {
          'good': [30, 31, 32],
        },
        searchErrors: {'bad': StateError('search failed')},
        articleErrors: {30: StateError('article failed')},
        articles: {
          31: const AnimejoyArticleDto(id: 31, shikimoriId: target),
          32: const AnimejoyArticleDto(id: 32, shikimoriId: target),
        },
        playlistErrors: {31: StateError('playlist failed')},
        playlists: {
          32: [_episode(1)],
        },
      );

      final releases = await _repository(
        source,
      ).findReleases(shikimoriId: '$target', titles: const ['bad', 'good']);

      expect(releases.map((release) => release.id), ['32']);
    },
  );

  test(
    'surfaces lookup errors when a search, article, or playlist has no result',
    () async {
      final searchFailure = _FakeAnimejoyDataSource(
        searchErrors: {'failed': StateError('search failed')},
      );
      await expectLater(
        _repository(
          searchFailure,
        ).findReleases(shikimoriId: '$target', titles: const ['failed']),
        throwsA(isA<StateError>()),
      );

      final articleFailure = _FakeAnimejoyDataSource(
        searchResults: {
          'Frieren': [40],
        },
        articleErrors: {40: StateError('article failed')},
      );
      await expectLater(
        _repository(
          articleFailure,
        ).findReleases(shikimoriId: '$target', titles: const ['Frieren']),
        throwsA(isA<StateError>()),
      );

      final playlistFailure = _FakeAnimejoyDataSource(
        searchResults: {
          'Frieren': [41],
        },
        articles: {41: const AnimejoyArticleDto(id: 41, shikimoriId: target)},
        playlistErrors: {41: StateError('playlist failed')},
      );
      await expectLater(
        _repository(
          playlistFailure,
        ).findReleases(shikimoriId: '$target', titles: const ['Frieren']),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'surfaces a failed query when other queries find no playable match',
    () async {
      final source = _FakeAnimejoyDataSource(
        searchResults: {
          'wrong season': [45],
        },
        searchErrors: {'failed title': StateError('search failed')},
        articles: {45: const AnimejoyArticleDto(id: 45, shikimoriId: 999)},
      );

      await expectLater(
        _repository(source).findReleases(
          shikimoriId: '$target',
          titles: const ['failed title', 'wrong season'],
        ),
        throwsA(isA<StateError>()),
      );
      expect(source.playlistCalls, isEmpty);
    },
  );

  test(
    'fetches a release by stable article id and rejects invalid ids locally',
    () async {
      final source = _FakeAnimejoyDataSource(
        playlists: {
          50: [_episode(1), _episode(2.5)],
        },
      );
      final repository = _repository(source);

      final release = await repository.fetchRelease(
        provider: OnlineProvider.animejoy,
        id: '50',
      );
      expect(release.id, '50');
      expect(
        [for (final episode in release.episodes) episode.id],
        ['50:1', '50:2.5'],
      );

      for (final id in ['x', '0', '-1']) {
        await expectLater(
          repository.fetchRelease(provider: OnlineProvider.animejoy, id: id),
          throwsA(isA<ResourceNotFoundException>()),
        );
      }
      for (final id in ['bad', '50:NaN', '50:-1', '50:1:2']) {
        await expectLater(
          repository.resolveStreams(
            provider: OnlineProvider.animejoy,
            episodeId: id,
          ),
          throwsA(isA<ResourceNotFoundException>()),
        );
      }
      expect(source.playlistCalls, [50]);
      expect(source.linkCalls, isEmpty);
    },
  );

  test(
    'refreshes the playlist and resolves only its supplied player URLs',
    () async {
      final source = _FakeAnimejoyDataSource(
        playlists: {
          60: [
            _episode(1, urls: ['https://animejoy.ru/old']),
          ],
        },
        players: {
          'https://animejoy.ru/new': [
            const VideoLinkDto(
              url: 'https://cdn.example/video.mp4',
              quality: 720,
              kind: VideoLinkKind.mp4,
            ),
          ],
        },
      );
      final repository = _repository(source);
      await repository.fetchRelease(
        provider: OnlineProvider.animejoy,
        id: '60',
      );
      source.playlists[60] = [
        _episode(
          1,
          urls: ['https://animejoy.ru/new', 'https://allvideo.example/new'],
        ),
      ];

      final streams = await repository.resolveStreams(
        provider: OnlineProvider.animejoy,
        episodeId: '60:1',
      );

      expect(source.playlistCalls, [60, 60]);
      expect(source.linkCalls, [
        'https://animejoy.ru/new',
        'https://allvideo.example/new',
      ]);
      expect(streams.single.format, OnlineStreamFormat.mp4);
      expect(streams.single.quality, 720);
    },
  );

  test(
    'orders quality descending and preserves AnimeJoy mirror at a tie',
    () async {
      const animeJoy = 'https://animejoy.ru/player';
      const allVideo = 'https://allvideo.example/player';
      final source = _FakeAnimejoyDataSource(
        playlists: {
          70: [
            _episode(1, urls: [animeJoy, allVideo]),
          ],
        },
        players: {
          animeJoy: [
            const VideoLinkDto(
              url: 'own-720',
              quality: 720,
              kind: VideoLinkKind.mp4,
            ),
            const VideoLinkDto(
              url: 'own-480',
              quality: 480,
              kind: VideoLinkKind.hls,
            ),
          ],
          allVideo: [
            const VideoLinkDto(
              url: 'all-1080',
              quality: 1080,
              kind: VideoLinkKind.dash,
            ),
            const VideoLinkDto(
              url: 'all-720',
              quality: 720,
              kind: VideoLinkKind.hls,
            ),
          ],
        },
      );

      final streams = await _repository(
        source,
      ).resolveStreams(provider: OnlineProvider.animejoy, episodeId: '70:1');

      expect(
        [for (final stream in streams) stream.quality],
        [1080, 720, 720, 480],
      );
      expect(
        [for (final stream in streams) stream.url],
        ['all-1080', 'own-720', 'all-720', 'own-480'],
      );
      expect(streams.first.format, OnlineStreamFormat.dash);
      expect(streams[2].format, OnlineStreamFormat.hls);
    },
  );

  test(
    'keeps one mirror when another fails and errors only when none resolve',
    () async {
      const broken = 'https://animejoy.ru/broken';
      const working = 'https://allvideo.example/working';
      final source = _FakeAnimejoyDataSource(
        playlists: {
          80: [
            _episode(1, urls: [broken, working]),
          ],
        },
        linkErrors: {broken: StateError('player failed')},
        players: {
          working: [
            const VideoLinkDto(
              url: 'working.mp4',
              quality: 480,
              kind: VideoLinkKind.mp4,
            ),
          ],
        },
      );
      final repository = _repository(source);

      expect(
        (await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '80:1',
        )).single.url,
        'working.mp4',
      );

      source.playlists[80] = [
        _episode(1, urls: [broken]),
      ];
      await expectLater(
        repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '80:1',
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'returns empty streams for missing player URLs or empty link results',
    () async {
      const empty = 'https://animejoy.ru/empty';
      final source = _FakeAnimejoyDataSource(
        playlists: {
          90: [_episode(1)],
        },
        players: {empty: const []},
      );
      final repository = _repository(source);

      expect(
        await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '90:1',
        ),
        isEmpty,
      );
      source.playlists[90] = [
        _episode(1, urls: [empty]),
      ];
      expect(
        await repository.resolveStreams(
          provider: OnlineProvider.animejoy,
          episodeId: '90:1',
        ),
        isEmpty,
      );
      expect(source.linkCalls, [empty]);
    },
  );

  test('invalid Shikimori ids do not search', () async {
    final source = _FakeAnimejoyDataSource();

    expect(
      await _repository(
        source,
      ).findReleases(shikimoriId: 'unknown', titles: const ['Frieren']),
      isEmpty,
    );
    expect(source.searchCalls, isEmpty);
    expect(source.articleCalls, isEmpty);
    expect(source.playlistCalls, isEmpty);
  });
}

AnimejoyOnlineSourcesRepository _repository(AnimejoyDataSource source) =>
    AnimejoyOnlineSourcesRepository(dataSource: source);

AnimejoyEpisodeDto _episode(
  num number, {
  String title = '',
  List<String> urls = const [],
}) => AnimejoyEpisodeDto(number: number, title: title, playerUrls: urls);

class _FakeAnimejoyDataSource extends AnimejoyDataSource {
  _FakeAnimejoyDataSource({
    this.searchResults = const {},
    this.articles = const {},
    Map<int, List<AnimejoyEpisodeDto>>? playlists,
    this.players = const {},
    this.searchErrors = const {},
    this.articleErrors = const {},
    this.playlistErrors = const {},
    this.linkErrors = const {},
  }) : playlists = playlists ?? {},
       super(dio: createVideoServerDio());

  final Map<String, List<int>> searchResults;
  final Map<int, AnimejoyArticleDto> articles;
  final Map<int, List<AnimejoyEpisodeDto>> playlists;
  final Map<String, List<VideoLinkDto>> players;
  final Map<String, Object> searchErrors;
  final Map<int, Object> articleErrors;
  final Map<int, Object> playlistErrors;
  final Map<String, Object> linkErrors;
  final searchCalls = <String>[];
  final articleCalls = <int>[];
  final playlistCalls = <int>[];
  final linkCalls = <String>[];

  @override
  Future<List<int>> search(String title) async {
    searchCalls.add(title);
    if (searchErrors[title] case final error?) throw error;
    return searchResults[title] ?? const [];
  }

  @override
  Future<AnimejoyArticleDto> article(int id) async {
    articleCalls.add(id);
    if (articleErrors[id] case final error?) throw error;
    return articles[id] ?? AnimejoyArticleDto(id: id);
  }

  @override
  Future<List<AnimejoyEpisodeDto>> episodes(int articleId) async {
    playlistCalls.add(articleId);
    if (playlistErrors[articleId] case final error?) throw error;
    return playlists[articleId] ?? const [];
  }

  @override
  Future<List<VideoLinkDto>> links(String playerUrl) async {
    linkCalls.add(playerUrl);
    if (linkErrors[playerUrl] case final error?) throw error;
    return players[playerUrl] ?? const [];
  }
}
