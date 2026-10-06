import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:iris/l10n/generated/app_localizations_en.dart';
import 'package:iris/l10n/generated/app_localizations_ru.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';

void main() {
  final en = AppLocalizationsEn();

  setUpAll(() => initializeDateFormatting('en'));

  test('joins anime metadata into one line', () {
    expect(
      formatAnimeMeta(
        en,
        kind: 'tv',
        status: 'ongoing',
        score: 8.5,
        episodes: 24,
        episodesAired: 10,
        airedOn: '2024-01-07',
      ),
      'TV · Ongoing · Score 8.50 · 10/24 episodes · Jan 7, 2024',
    );
  });

  test('shows the total for released titles without aired episodes', () {
    expect(formatEpisodes(en, 'released', 37, 0), '37 episodes');
    expect(formatEpisodes(AppLocalizationsRu(), 'released', 21, 0), '21 серия');
  });

  test('skips unknown score, episodes and date', () {
    expect(
      formatAnimeMeta(
        en,
        kind: 'movie',
        status: 'anons',
        score: 0,
        episodes: 0,
        episodesAired: 0,
        airedOn: '',
      ),
      'Movie · Announced',
    );
  });
}
