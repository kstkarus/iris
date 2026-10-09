// Runs the live AniLibria chain for one title, to see quickly whether the
// site still answers the way the parsers expect. Not part of `flutter test`:
// it needs the network.
//
//   dart run tool/online_sources_smoke.dart [shikimoriId] [title...]
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:iris/features/online_sources/data/datasources/anilibria_data_source.dart';
import 'package:iris/features/online_sources/data/repositories/anilibria_online_sources_repository.dart';
import 'package:iris/shared/network/anilibria_api_client.dart';
import 'package:iris/shared/network/anilibria_dio_factory.dart';

Future<void> main(List<String> args) async {
  final shikimoriId = args.isEmpty ? '52991' : args.first;
  final titles = args.length > 1 ? args.sublist(1) : const ['Frieren'];
  final repository = AnilibriaOnlineSourcesRepository(
    dataSource: AnilibriaDataSource(
      client: AnilibriaApiClient(dio: createAnilibriaDio()),
    ),
  );

  final releases = await repository.findReleases(
    shikimoriId: shikimoriId,
    titles: titles,
  );
  print('AniLibria: ${releases.length} release(s) for Shikimori $shikimoriId');
  if (releases.isEmpty) exit(1);
  for (final release in releases) {
    print(
      '  ${release.id} "${release.title}" (${release.dub}), '
      '${release.episodes.length} episodes',
    );
  }
  final episode = releases.first.episodes.first;
  final streams = await repository.resolveStreams(
    provider: releases.first.provider,
    episodeId: episode.id,
  );
  print(
    '  episode ${episode.number}: '
    '${[for (final s in streams) '${s.quality} ${s.format.name}'].join(', ')}',
  );
  exit(streams.isEmpty ? 1 : 0);
}
