import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_failure.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

const _link = 'online:anilibria/9542';

const _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  title: 'Провожающая в последний путь Фрирен',
  dub: 'AniLibria',
  episodes: [
    OnlineEpisode(
      id: 'e1',
      number: 1,
      title: '«Конец приключений»',
      duration: Duration(minutes: 26),
    ),
    OnlineEpisode(id: 'e2', number: 1.5),
  ],
);

void main() {
  late _FakeOnlineSources sources;
  late OnlinePlayerRepository repository;

  setUp(() {
    sources = _FakeOnlineSources();
    repository = OnlinePlayerRepository(repository: sources);
  });

  test('offers the episodes as the files of the release', () async {
    final source = await repository.prepareSource(magnet: _link);

    expect(sources.fetched, [(OnlineProvider.anilibria, '9542')]);
    expect(source.sessionId, _link);
    expect(source.files, const [
      PlayerVideoFile(
        index: 0,
        name: '01 «Конец приключений»',
        size: 0,
        extension: '',
        episodeNumber: 1,
        title: '«Конец приключений»',
        duration: Duration(minutes: 26),
      ),
      // A special keeps its place but has no whole number.
      PlayerVideoFile(index: 1, name: '1.5', size: 0, extension: ''),
    ]);
  });

  test('plays an episode from its freshly issued best stream', () async {
    await repository.prepareSource(magnet: _link);

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 0)
        .toList();

    expect(sources.resolved, ['e1']);
    // The release is not asked for again.
    expect(sources.fetched, hasLength(1));
    expect(updates, const [
      PlayerLaunchReadyUpdate(
        PlayerSession(
          sessionId: _link,
          streamUrl: 'https://cdn.example.test/e1/1080.m3u8',
          httpHeaders: {'Referer': 'https://example.test/'},
        ),
      ),
    ]);
  });

  test('fetches the release when playback starts from history', () async {
    await repository
        .startPlayback(sessionId: _link, fileIndex: 0)
        .drain<void>();

    expect(sources.fetched, hasLength(1));
    expect(sources.resolved, ['e1']);
  });

  test('fails to start an episode without streams', () async {
    sources.streams = const [];

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 0)
        .toList();

    expect(updates, const [
      PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart),
    ]);
  });

  test('fails to start when the server does not answer', () async {
    sources.failResolve = true;

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 0)
        .toList();

    expect(updates, const [
      PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart),
    ]);
  });

  test('fails to start an episode the release does not have', () async {
    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 5)
        .toList();

    expect(updates, const [
      PlayerLaunchFailureUpdate(PlayerLaunchFailure.unableToStart),
    ]);
    expect(sources.resolved, isEmpty);
  });

  test('asks for the release again after the session ends', () async {
    await repository.prepareSource(magnet: _link);
    await repository.disposePlayback(sessionId: _link);
    await repository.prepareSource(magnet: _link);

    expect(sources.fetched, hasLength(2));
  });

  test('reports no torrent stats', () async {
    expect(await repository.watchPlaybackStats(sessionId: _link).toList(), []);
  });
}

class _FakeOnlineSources implements OnlineSourcesRepository {
  final fetched = <(OnlineProvider, String)>[];
  final resolved = <String>[];
  bool failResolve = false;
  List<OnlineStream> streams = const [
    OnlineStream(
      url: 'https://cdn.example.test/e1/1080.m3u8',
      quality: 1080,
      format: OnlineStreamFormat.hls,
      httpHeaders: {'Referer': 'https://example.test/'},
    ),
    OnlineStream(
      url: 'https://cdn.example.test/e1/720.m3u8',
      quality: 720,
      format: OnlineStreamFormat.hls,
    ),
  ];

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    fetched.add((provider, id));
    return _release;
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    resolved.add(episodeId);
    if (failResolve) throw StateError('offline');
    return streams;
  }

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => throw UnimplementedError();
}
