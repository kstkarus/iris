import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/combined_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_http_adapter.dart';
import '../../../../helpers/memory_online_quality_preferences.dart';

const _link = OnlineSourceLink(
  provider: 'animejoy',
  releaseId: '5682',
  animeId: '63181',
);

void main() {
  late List<RequestOptions> requests;

  FakeReply respond(RequestOptions options, {bool allVideoOnly = false}) {
    requests.add(options);
    final uri = options.uri;
    if (uri.path == '/index.php') {
      if (uri.queryParameters.containsKey('story')) {
        return FakeReply.text(200, readFixture('animejoy/search.html'));
      }
      final article = readFixture('animejoy/article.html');
      return FakeReply.text(
        200,
        uri.queryParameters['newsid'] == '5682'
            ? article
            : article.replaceAll('63181', '100'),
      );
    }
    if (uri.path == '/engine/ajax/playlists.php') {
      var playlist = readFixture('animejoy/playlists.json');
      if (allVideoOnly) playlist = playlist.replaceAll('Наш плеер', 'Ignored');
      return FakeReply.text(200, playlist);
    }
    if (uri.host == 'fsst.online' && uri.path.startsWith('/embed/')) {
      return FakeReply.text(200, readFixture('animejoy/allvideo.html'));
    }
    if (uri.host == 'cdn.example' || uri.host == 'media.example') {
      return const FakeReply.text(
        200,
        'main episode',
        headers: {
          'content-length': ['12'],
        },
      );
    }
    return const FakeReply.text(404, 'Unexpected request');
  }

  CombinedOnlineSourcesRepository sources({bool allVideoOnly = false}) {
    final dio = createVideoServerDio()
      ..httpClientAdapter = FakeHttpAdapter(
        (options) => respond(options, allVideoOnly: allVideoOnly),
      );
    return CombinedOnlineSourcesRepository(
      providers: {
        OnlineProvider.animejoy: AnimejoyOnlineSourcesRepository(
          dataSource: AnimejoyDataSource(dio: dio),
        ),
      },
    );
  }

  setUp(() => requests = []);

  test(
    'discovered AnimeJoy opens in the shared player and renews quality',
    () async {
      final repository = sources();
      final releases = await repository.findReleases(
        shikimoriId: '63181',
        titles: const ['Tougen Anki'],
      );
      expect(releases.single.id, '5682');
      expect(releases.single.dub, 'AnimeJoy');
      expect(releases.single.bestQuality, isNull);
      expect(_link.progressKey, 'online:anime/63181');

      final preferences = MemoryOnlineQualityPreferences();
      final player = OnlinePlayerRepository(
        repository: repository,
        qualityPreferences: preferences,
      );
      final prepared = await player.prepareSource(magnet: _link.toString());
      expect(prepared.files.map((file) => file.index), [1, 100150, 2]);
      expect(prepared.files.first.name, '01');

      final updates = await player
          .startPlayback(sessionId: prepared.sessionId, fileIndex: 1)
          .toList();
      final session = (updates.single as PlayerLaunchReadyUpdate).session;
      expect(session.streamUrl, 'https://cdn.example/01-1080.mp4');
      expect(session.qualities, [1080, 720, 360]);

      preferences.watching = 720;
      final renewed = await player.renewSession(session);
      expect(renewed?.streamUrl, 'https://cdn.example/01-720.mp4');
      expect(renewed?.sessionId, session.sessionId);
      await player.disposePlayback(sessionId: session.sessionId);

      expect(
        requests.any(
          (request) =>
              request.uri.host.contains('kodik') ||
              request.uri.host == 'ads.example',
        ),
        isFalse,
      );
    },
  );

  test('an AllVideo-only title still uses the shared player', () async {
    final player = OnlinePlayerRepository(
      repository: sources(allVideoOnly: true),
    );
    final updates = await player
        .startPlayback(sessionId: _link.toString(), fileIndex: 1)
        .toList();
    final session = (updates.single as PlayerLaunchReadyUpdate).session;
    expect(session.streamUrl, 'https://media.example/get_file/episode.mp4/');
    expect(session.qualities, [1080, 360]);
    await player.disposePlayback(sessionId: session.sessionId);
  });

  test(
    'AnimeJoy downloads through the existing MP4 queue in the chosen quality',
    () async {
      final directory = await Directory.systemTemp.createTemp('iris_animejoy_');
      addTearDown(() => directory.delete(recursive: true));
      final downloader = OnlineEpisodeDownloader(
        repository: sources(),
        dio: fakeDio(respond),
      );
      final prepared = await downloader.episodes(_link);
      expect(prepared.qualities, [1080, 720, 360]);
      expect(prepared.files.map((file) => file.index), [1, 100150, 2]);

      final task = downloader.start(
        link: _link,
        fileIndex: 1,
        directory: directory,
        maxQuality: 720,
      );
      final file = await task.done;
      expect(await file!.readAsString(), 'main episode');
      expect(requests.last.uri.toString(), 'https://cdn.example/01-720.mp4');
      expect(file.path, endsWith('episode.mp4'));
    },
  );
}
