import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';

void main() {
  group('AnimeDetailsCubit', () {
    test('does not throw when closed before the details arrive', () async {
      final pending = Completer<AnimeDetails>();
      final cubit = AnimeDetailsCubit(
        animeId: '5114',
        repository: _PendingAnimeDetailsRepository(pending.future),
      );

      final load = cubit.loadAnime();
      await cubit.close();
      pending.complete(_details);

      await expectLater(load, completes);
    });

    test('does not throw when closed before the request fails', () async {
      final pending = Completer<AnimeDetails>();
      final cubit = AnimeDetailsCubit(
        animeId: '5114',
        repository: _PendingAnimeDetailsRepository(pending.future),
      );

      final load = cubit.loadAnime();
      await cubit.close();
      pending.completeError(Exception('Repository failure'));

      await expectLater(load, completes);
    });

    test(
      'emits loading then success when repository returns details',
      () async {
        final cubit = AnimeDetailsCubit(
          animeId: '5114',
          repository: _SuccessAnimeDetailsRepository(_details),
        );

        expectLater(
          cubit.stream,
          emitsInOrder([
            const AnimeDetailsLoading(),
            const AnimeDetailsSuccess(_details),
          ]),
        );

        await cubit.loadAnime();
      },
    );

    test('emits loading then failure when repository throws', () async {
      final cubit = AnimeDetailsCubit(
        animeId: '5114',
        repository: _FailureAnimeDetailsRepository(),
      );

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AnimeDetailsLoading(),
          const AnimeDetailsFailure(),
        ]),
      );

      await cubit.loadAnime();
    });
  });
}

class _SuccessAnimeDetailsRepository implements AnimeDetailsRepository {
  const _SuccessAnimeDetailsRepository(this.details);

  final AnimeDetails details;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async => details;
}

class _FailureAnimeDetailsRepository implements AnimeDetailsRepository {
  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) {
    throw Exception('Repository failure');
  }
}

class _PendingAnimeDetailsRepository implements AnimeDetailsRepository {
  const _PendingAnimeDetailsRepository(this.pending);

  final Future<AnimeDetails> pending;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) => pending;
}

const _details = AnimeDetails(
  id: '5114',
  name: 'Fullmetal Alchemist: Brotherhood',
  russian: 'Fullmetal Alchemist: Brotherhood RU',
  description:
      'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
  kind: 'tv',
  score: 9.12,
  status: 'released',
  episodes: 64,
  episodesAired: 64,
  airedOn: '2009-04-05',
  posterOriginalUrl: 'https://shikimori.one/posters/5114/original.jpg',
);
