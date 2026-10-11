import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';

import '../../anime_details_test_doubles.dart';

void main() {
  group('AnimeDetailsCubit', () {
    for (final fails in [false, true]) {
      final outcome = fails ? 'the request fails' : 'the details arrive';
      test('does not throw when closed before $outcome', () async {
        final pending = Completer<AnimeDetails>();
        final cubit = AnimeDetailsCubit(
          animeId: '5114',
          repository: PendingAnimeDetailsRepository(pending.future),
        );

        final load = cubit.loadAnime();
        await cubit.close();
        if (fails) {
          pending.completeError(Exception('Repository failure'));
        } else {
          pending.complete(fmaDetails);
        }

        await expectLater(load, completes);
      });
    }

    test(
      'emits loading then success when repository returns details',
      () async {
        final cubit = AnimeDetailsCubit(
          animeId: '5114',
          repository: const FixedAnimeDetailsRepository(),
        );

        expectLater(
          cubit.stream,
          emitsInOrder([
            const AnimeDetailsLoading(),
            const AnimeDetailsSuccess(fmaDetails),
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

class _FailureAnimeDetailsRepository implements AnimeDetailsRepository {
  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) {
    throw Exception('Repository failure');
  }
}
