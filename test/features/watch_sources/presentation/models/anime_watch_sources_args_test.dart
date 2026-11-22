import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';

void main() {
  test('searches by the main and the English name', () {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: '52991',
      animeTitles: const AnimeTitles(
        name: 'Sousou no Frieren',
        russian: 'Провожающая в последний путь Фрирен',
        english: "Frieren: Beyond Journey's End",
      ),
    );

    expect(args.animeTitles.russian, 'Провожающая в последний путь Фрирен');
    expect(args.searchTitles, [
      'Sousou no Frieren',
      "Frieren: Beyond Journey's End",
    ]);
  });

  test('searches a name once when the English one repeats it', () {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: '1535',
      animeTitles: const AnimeTitles(
        name: 'Death Note',
        english: ' death note ',
      ),
    );

    expect(args.searchTitles, ['Death Note']);
  });

  test('leaves out a missing English name', () {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: '1',
      animeTitles: const AnimeTitles(name: 'Mushishi'),
    );

    expect(args.searchTitles, ['Mushishi']);
  });
}
