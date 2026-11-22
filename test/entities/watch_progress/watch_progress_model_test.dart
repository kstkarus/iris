import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/data/watch_progress_model.dart';

const _legacy = <String, Object>{
  'torrentKey': 'abc',
  'fileIndex': 1,
  'fileName': 'Episode 02.mkv',
  'magnet': 'magnet:?xt=urn:btih:abc',
  'sourceTitle': 'Release',
  'positionMs': 120000,
  'durationMs': 1440000,
  'updatedAt': '2026-11-21T12:00:00.000Z',
  'animeId': '52991',
  'animeTitle': 'Sousou no Frieren',
};

void main() {
  test('older progress still displays its stored anime title', () {
    final progress = WatchProgressModel.fromJson(_legacy)!;

    expect(
      progress.displayTitles,
      const AnimeTitles(name: 'Sousou no Frieren'),
    );
    expect(WatchProgressModel.toJson(progress), _legacy);
  });

  test('persisted translations survive changes to history visibility', () {
    final json = {
      ..._legacy,
      'animeRussian': 'Провожающая в последний путь Фрирен',
      'animeEnglish': "Frieren: Beyond Journey's End",
    };
    final progress = WatchProgressModel.fromJson(json)!;

    expect(
      progress.displayTitles,
      const AnimeTitles(
        name: 'Sousou no Frieren',
        russian: 'Провожающая в последний путь Фрирен',
        english: "Frieren: Beyond Journey's End",
      ),
    );
    final hidden = progress.copyWith(hiddenFromContinueWatching: true);
    expect(WatchProgressModel.toJson(hidden), {
      ...json,
      'hiddenFromContinueWatching': true,
    });
  });
}
