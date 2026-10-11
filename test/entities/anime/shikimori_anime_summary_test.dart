import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/data/shikimori_anime_summary.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';

void main() {
  test('reads the summary fields and the list poster', () {
    expect(
      parseShikimoriAnimeSummary({
        'id': '52991',
        'name': 'Sousou no Frieren',
        'russian': 'Провожающая в последний путь Фрирен',
        'english': "Frieren: Beyond Journey's End",
        'kind': 'tv',
        'score': 9.3,
        'status': 'ongoing',
        'episodes': 28,
        'episodesAired': 7,
        'airedOn': {
          'year': 2023,
          'month': 9,
          'day': null,
          'date': '2023-09-01',
        },
        'poster': {'mainUrl': 'main.jpg', 'originalUrl': 'original.jpg'},
        'nextEpisodeAt': '2026-10-12T15:00:00+03:00',
      }),
      AnimeSummary(
        id: '52991',
        name: 'Sousou no Frieren',
        russian: 'Провожающая в последний путь Фрирен',
        english: "Frieren: Beyond Journey's End",
        kind: 'tv',
        score: 9.3,
        status: 'ongoing',
        episodes: 28,
        episodesAired: 7,
        airedOn: '2023-09',
        posterUrl: 'main.jpg',
        nextEpisodeAt: DateTime.utc(2026, 10, 12, 12),
      ),
    );
  });

  test('takes the poster size it is asked for', () {
    final anime = parseShikimoriAnimeSummary({
      'id': 1,
      'poster': {'mainUrl': 'main.jpg', 'originalUrl': 'original.jpg'},
    }, posterUrlField: 'originalUrl');

    expect(anime?.posterUrl, 'original.jpg');
  });

  test('missing or mistyped fields read as empty or zero', () {
    expect(
      parseShikimoriAnimeSummary({
        'id': 7,
        'name': 12,
        'score': '8.1',
        'episodes': null,
        'airedOn': 'soon',
        'poster': null,
      }),
      const AnimeSummary(
        id: '7',
        name: '',
        russian: '',
        kind: '',
        score: 0,
        status: '',
        episodes: 0,
        episodesAired: 0,
        airedOn: '',
        posterUrl: '',
      ),
    );
  });

  test('no anime without an id', () {
    expect(parseShikimoriAnimeSummary({'name': 'Frieren'}), isNull);
    expect(parseShikimoriAnimeSummary(null), isNull);
    expect(parseShikimoriAnimeSummary(const ['52991']), isNull);
  });
}
