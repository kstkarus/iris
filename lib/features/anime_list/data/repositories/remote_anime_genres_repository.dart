import 'package:iris/features/anime_list/domain/entities/anime_genre.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_genres_repository.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

/// Asks Shikimori once a session: the genres hardly ever change. A failed
/// request is asked again next time.
class RemoteAnimeGenresRepository implements AnimeGenresRepository {
  RemoteAnimeGenresRepository({required ShikimoriGraphQlClient client})
    : _client = client;

  final ShikimoriGraphQlClient _client;
  Future<List<AnimeGenre>>? _genres;

  @override
  Future<List<AnimeGenre>> genres() =>
      _genres ??= _fetch()
        ..catchError((Object _) {
          _genres = null;
          return const <AnimeGenre>[];
        });

  Future<List<AnimeGenre>> _fetch() async {
    final items = await _client.queryList('genres', document: _genresQuery);
    return [for (final item in items) ?_parse(item)];
  }

  static AnimeGenre? _parse(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id == null || name is! String) return null;
    final russian = json['russian'];
    return AnimeGenre(
      id: '$id',
      name: name,
      russian: russian is String ? russian : '',
      kind: switch (json['kind']) {
        'demographic' => AnimeGenreKind.demographic,
        'theme' => AnimeGenreKind.theme,
        _ => AnimeGenreKind.genre,
      },
    );
  }
}

const _genresQuery = '''
query AnimeGenres {
  genres(entryType: Anime) {
    id
    name
    russian
    kind
  }
}
''';
