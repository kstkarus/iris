import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/data/repositories/remote_anime_genres_repository.dart';
import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

import '../../../../helpers/fake_http_adapter.dart';

void main() {
  late FakeReply reply;
  late FakeHttpAdapter adapter;

  RemoteAnimeGenresRepository repository() {
    adapter = FakeHttpAdapter((_) => reply);
    return RemoteAnimeGenresRepository(
      client: ShikimoriGraphQlClient(
        dio: Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
          ..httpClientAdapter = adapter,
      ),
    );
  }

  const genres = FakeReply(200, {
    'data': {
      'genres': [
        {'id': '1', 'name': 'Action', 'russian': 'Экшен', 'kind': 'genre'},
        {
          'id': '27',
          'name': 'Shounen',
          'russian': 'Сёнен',
          'kind': 'demographic',
        },
        {'id': '38', 'name': 'Military', 'russian': null, 'kind': 'theme'},
      ],
    },
  });

  test('reads genres, audiences and themes once a session', () async {
    reply = genres;
    final genresRepository = repository();

    final first = await genresRepository.genres();
    await genresRepository.genres();

    expect(first.map((genre) => genre.kind), [
      AnimeGenreKind.genre,
      AnimeGenreKind.demographic,
      AnimeGenreKind.theme,
    ]);
    expect(first.first.russian, 'Экшен');
    expect(first.last.russian, '');
    expect(adapter.requests, hasLength(1));
  });

  test('a failed request is asked again next time', () async {
    reply = const FakeReply(503);
    final genresRepository = repository();

    await expectLater(genresRepository.genres(), throwsA(isA<Exception>()));
    reply = genres;

    expect(await genresRepository.genres(), hasLength(3));
  });
}
