import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';

void main() {
  test('searches by the main and the English name', () {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: '52991',
      name: 'Sousou no Frieren',
      english: "Frieren: Beyond Journey's End",
    );

    expect(args.animeTitle, 'Sousou no Frieren');
    expect(args.searchTitles, [
      'Sousou no Frieren',
      "Frieren: Beyond Journey's End",
    ]);
  });

  test('searches a name once when the English one repeats it', () {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: '1535',
      name: 'Death Note',
      english: ' death note ',
    );

    expect(args.searchTitles, ['Death Note']);
  });

  test('leaves out a missing English name', () {
    final args = AnimeWatchSourcesArgs.forAnime(animeId: '1', name: 'Mushishi');

    expect(args.searchTitles, ['Mushishi']);
  });
}
