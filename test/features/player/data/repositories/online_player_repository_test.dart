import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';

import '../../../../helpers/memory_online_quality_preferences.dart';

const _link = 'online:anilibria/9542';

const _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
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
        index: 1,
        name: '01 «Конец приключений»',
        size: 0,
        extension: '',
        episodeNumber: 1,
        title: '«Конец приключений»',
        duration: Duration(minutes: 26),
      ),
      // A special is filed under its number too, past every whole one.
      PlayerVideoFile(
        index: 100150,
        name: '1.5',
        size: 0,
        extension: '',
        episodeNumber: 1.5,
      ),
    ]);
  });

  test('plays an episode from its freshly issued best stream', () async {
    await repository.prepareSource(magnet: _link);

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .toList();

    expect(sources.resolved, ['e1']);
    // The release is not asked for again.
    expect(sources.fetched, hasLength(1));
    expect(updates, const [
      PlayerLaunchReadyUpdate(
        PlayerSession(
          sessionId: _link,
          streamUrl: 'https://cdn.example.test/e1/1080.m3u8',
          qualities: [1080, 720],
          quality: 1080,
        ),
      ),
    ]);
  });

  test('plays the quality chosen for watching, read as each episode '
      'starts', () async {
    final preferences = MemoryOnlineQualityPreferences(watching: 720);
    repository = OnlinePlayerRepository(
      repository: sources,
      qualityPreferences: preferences,
    );

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .toList();
    expect(
      (updates.single as PlayerLaunchReadyUpdate).session.streamUrl,
      'https://cdn.example.test/e1/720.m3u8',
    );

    preferences.watching = null;
    final renewed = await repository.renewSession(
      (updates.single as PlayerLaunchReadyUpdate).session,
    );
    expect(renewed?.quality, 1080);
  });

  test('fetches the release when playback starts from history', () async {
    await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .drain<void>();

    expect(sources.fetched, hasLength(1));
    expect(sources.resolved, ['e1']);
  });

  test('files every episode under its number, as every dub does', () async {
    sources.release = const OnlineRelease(
      provider: OnlineProvider.yummyAnime,
      id: '10661:AniDUB',
      dub: 'AniDUB',
      episodes: [
        OnlineEpisode(id: 'e5', number: 5),
        OnlineEpisode(id: 'e6', number: 6),
        // A number given twice keeps the first.
        OnlineEpisode(id: 'e6b', number: 6),
      ],
    );

    final source = await repository.prepareSource(magnet: _link);
    expect([for (final file in source.files) file.index], [5, 6, 300002]);

    await repository
        .startPlayback(sessionId: _link, fileIndex: 6)
        .drain<void>();
    expect(sources.resolved, ['e6']);
  });

  test('a special keeps its index in every dub', () async {
    final withEpisodeOne = await repository.prepareSource(magnet: _link);
    sources.release = const OnlineRelease(
      provider: OnlineProvider.yummyAnime,
      id: '10661:AniDUB',
      dub: 'AniDUB',
      episodes: [
        OnlineEpisode(id: 's', number: 1.5),
        OnlineEpisode(id: 'e2', number: 2),
      ],
    );
    final other = OnlinePlayerRepository(repository: sources);
    final withoutEpisodeOne = await other.prepareSource(magnet: _link);

    expect(
      withEpisodeOne.files.last.index,
      withoutEpisodeOne.files.first.index,
    );
  });

  test('stops waiting for a release when the picker goes', () async {
    sources.pendingRelease = Completer<OnlineRelease>();
    final cancelled = Completer<void>();

    final preparation = repository.prepareSource(
      magnet: _link,
      cancelled: cancelled.future,
    );
    cancelled.complete();

    await expectLater(
      preparation,
      throwsA(isA<PreparationCancelledException>()),
    );
  });

  test('cancelling a launch does not wait for the server', () async {
    await repository.prepareSource(magnet: _link);
    sources.pendingStreams = Completer<List<OnlineStream>>();
    final updates = <PlayerLaunchUpdate>[];

    final subscription = repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .listen(updates.add);
    await pumpEventQueue();
    // Completes although the server has not answered.
    await subscription.cancel();

    sources.pendingStreams!.complete(sources.streams);
    await pumpEventQueue();
    expect(updates, isEmpty, reason: 'a late answer is dropped');
  });

  test('fails to start an episode without streams', () async {
    sources.streams = const [];

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .toList();

    expect(updates, const [PlayerLaunchFailureUpdate()]);
  });

  test('fails to start when the server does not answer', () async {
    sources.failResolve = true;

    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .toList();

    expect(updates, const [PlayerLaunchFailureUpdate()]);
  });

  test('fails to start an episode the release does not have', () async {
    final updates = await repository
        .startPlayback(sessionId: _link, fileIndex: 5)
        .toList();

    expect(updates, const [PlayerLaunchFailureUpdate()]);
    expect(sources.resolved, isEmpty);
  });

  test('asks for the release again after the session ends', () async {
    await repository.prepareSource(magnet: _link);
    await repository.disposePlayback(sessionId: _link);
    await repository.prepareSource(magnet: _link);

    expect(sources.fetched, hasLength(2));
  });

  test('renews the link of the episode that plays', () async {
    await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .drain<void>();
    sources.streams = const [
      OnlineStream(
        url: 'https://cdn.example.test/e1/1080.m3u8?fresh',
        quality: 1080,
        format: OnlineStreamFormat.hls,
      ),
    ];

    final renewed = await repository.renewSession(
      const PlayerSession(
        sessionId: _link,
        streamUrl: 'https://cdn.example.test/e1/1080.m3u8',
      ),
    );

    expect(sources.resolved, ['e1', 'e1']);
    expect(
      renewed,
      const PlayerSession(
        sessionId: _link,
        streamUrl: 'https://cdn.example.test/e1/1080.m3u8?fresh',
        qualities: [1080],
        quality: 1080,
      ),
    );
  });

  test('renews nothing once the episode stopped', () async {
    await repository
        .startPlayback(sessionId: _link, fileIndex: 1)
        .drain<void>();
    await repository.stopPlayback(sessionId: _link);

    final renewed = await repository.renewSession(
      const PlayerSession(sessionId: _link, streamUrl: 'https://old.test'),
    );

    expect(renewed, isNull);
    expect(sources.resolved, ['e1']);
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
    ),
    OnlineStream(
      url: 'https://cdn.example.test/e1/720.m3u8',
      quality: 720,
      format: OnlineStreamFormat.hls,
    ),
  ];

  OnlineRelease release = _release;
  Completer<OnlineRelease>? pendingRelease;
  Completer<List<OnlineStream>>? pendingStreams;

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    fetched.add((provider, id));
    return pendingRelease?.future ?? release;
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    resolved.add(episodeId);
    if (failResolve) throw StateError('offline');
    return pendingStreams?.future ?? streams;
  }

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => throw UnimplementedError();
}
