import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/presentation/cubit/continue_watching_posters_cubit.dart';

void main() {
  test(
    'reuses catalog covers and loads each missing title only once',
    () async {
      final repository = _Details();
      final cubit = ContinueWatchingPostersCubit(repository: repository);
      addTearDown(cubit.close);
      final items = [_progress('known'), _progress('missing'), _progress('')];
      final first = cubit.load(items, {'known': 'cached.webp'});
      final second = cubit.load(items, {'known': 'cached.webp'});
      expect(cubit.state['known'], 'cached.webp');
      expect(repository.calls, ['missing']);
      repository.pending.complete(_details('missing'));
      await Future.wait([first, second]);
      await cubit.load(items, const {});
      expect(repository.calls, ['missing']);
      expect(cubit.state['missing'], 'missing.webp');
    },
  );

  test('a failed cover is optional and can retry on another opening', () async {
    final repository = _Details();
    final cubit = ContinueWatchingPostersCubit(repository: repository);
    addTearDown(cubit.close);
    final load = cubit.load([_progress('a')], const {});
    repository.pending.completeError(StateError('offline'));
    await load;
    expect(cubit.state, isEmpty);
    repository.pending = Completer();
    final retry = cubit.load([_progress('a')], const {});
    repository.pending.complete(_details('a'));
    await retry;
    expect(cubit.state['a'], 'a.webp');
  });

  test('late cover completion after closing the button is ignored', () async {
    final repository = _Details();
    final cubit = ContinueWatchingPostersCubit(repository: repository);
    final load = cubit.load([_progress('a')], const {});
    await cubit.close();
    repository.pending.complete(_details('a'));
    await load;
    expect(cubit.state, isEmpty);
  });
}

class _Details implements AnimeDetailsRepository {
  final calls = <String>[];
  Completer<AnimeDetails> pending = Completer();
  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) {
    calls.add(id);
    return pending.future;
  }
}

AnimeDetails _details(String id) => AnimeDetails(
  anime: AnimeSummary(
    id: id,
    name: id,
    russian: '',
    kind: 'tv',
    score: 8,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: '',
    posterUrl: '$id.webp',
  ),
  description: '',
);

WatchProgress _progress(String id) => WatchProgress(
  animeId: id,
  animeTitle: id,
  torrentKey: id,
  fileIndex: 0,
  fileName: '',
  magnet: '',
  sourceTitle: '',
  position: const Duration(minutes: 1),
  duration: const Duration(minutes: 24),
  updatedAt: DateTime(2026),
);
