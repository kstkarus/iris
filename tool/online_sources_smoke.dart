// Runs the live chain of every online provider for one title, to see
// quickly whether the sites still answer the way the parsers expect. Not
// part of `flutter test`: it needs the network.
//
//   dart run tool/online_sources_smoke.dart [shikimoriId] [title...]
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:iris/features/online_sources/data/datasources/aksor_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/anilibria_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/kodik_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/yummy_anime_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/anilibria_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/data/repositories/yummy_anime_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/anilibria_api.dart';
import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/video_server_dio_factory.dart';
import 'package:iris/shared/network/yummy_anime_api.dart';
import 'package:iris/shared/network/yummy_anime_api_client.dart';

/// Releases per provider whose first episode is resolved.
const _resolvedPerProvider = 3;

Future<void> main(List<String> args) async {
  final shikimoriId = args.isEmpty ? '52991' : args.first;
  final titles = args.length > 1 ? args.sublist(1) : const ['Frieren'];
  final videoServers = createVideoServerDio();
  final providers = <OnlineProvider, OnlineSourcesRepository>{
    OnlineProvider.anilibria: AnilibriaOnlineSourcesRepository(
      dataSource: AnilibriaDataSource(
        client: AnilibriaApiClient(
          dio: createJsonApiDio(baseUrl: AnilibriaApi.baseUrl),
        ),
      ),
    ),
    OnlineProvider.yummyAnime: YummyAnimeOnlineSourcesRepository(
      dataSource: YummyAnimeDataSource(
        client: YummyAnimeApiClient(
          dio: createJsonApiDio(
            baseUrl: YummyAnimeApi.baseUrl,
            receiveTimeout: const Duration(seconds: 30),
          ),
        ),
      ),
      kodik: KodikDataSource(dio: videoServers),
      aksor: AksorDataSource(dio: videoServers),
    ),
    OnlineProvider.animejoy: AnimejoyOnlineSourcesRepository(
      dataSource: AnimejoyDataSource(dio: videoServers),
    ),
  };

  var failed = false;
  for (final MapEntry(key: provider, value: repository) in providers.entries) {
    try {
      final releases = await repository.findReleases(
        shikimoriId: shikimoriId,
        titles: titles,
      );
      print('${provider.name}: ${releases.length} release(s)');
      if (releases.isEmpty) failed = true;
      for (final (index, release) in releases.indexed) {
        final line =
            '  "${release.dub}", ${release.episodes.length} episodes'
            '${release.bestQuality == null ? '' : ', up to ${release.bestQuality}p'}';
        if (index >= _resolvedPerProvider || release.episodes.isEmpty) {
          print(line);
          continue;
        }
        final streams = await repository.resolveStreams(
          provider: provider,
          episodeId: release.episodes.first.id,
        );
        final kinds = [
          for (final s in streams) '${s.quality} ${s.format.name}',
        ].join(', ');
        print('$line; episode ${release.episodes.first.number}: $kinds');
        if (streams.isEmpty) failed = true;
      }
    } on Object catch (error) {
      print('${provider.name}: FAILED $error');
      failed = true;
    }
  }
  exit(failed ? 1 : 0);
}
