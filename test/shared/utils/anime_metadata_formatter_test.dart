import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:iris/l10n/generated/app_localizations_en.dart';
import 'package:iris/l10n/generated/app_localizations_ru.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';

void main() {
  final en = AppLocalizationsEn();

  test('shows the total for released titles without aired episodes', () {
    expect(formatEpisodes(en, 'released', 37, 0), '37 episodes');
    expect(formatEpisodes(AppLocalizationsRu(), 'released', 21, 0), '21 серия');
  });

  group('formatAiredOn', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ru');
    });

    test('shows only the year when only the year is known', () {
      expect(formatAiredOn(en, '2028'), '2028');
    });

    test('shows the month and year when the day is unknown', () {
      expect(formatAiredOn(en, '2028-03'), 'March 2028');
    });

    test('shows the full date when it is known', () {
      expect(formatAiredOn(en, '2028-03-15'), 'Mar 15, 2028');
    });

    test('leaves text that is not a date as it is', () {
      expect(formatAiredOn(en, 'soon'), 'soon');
      expect(formatAiredOn(en, ''), '');
    });
  });

  group('formatNextEpisodeTime', () {
    final ru = AppLocalizationsRu();
    final now = DateTime(2026, 10, 10, 20);

    setUpAll(() async {
      await initializeDateFormatting('en');
      await initializeDateFormatting('ru');
    });

    test('names today and tomorrow with the time', () {
      expect(
        formatNextEpisodeTime(en, DateTime(2026, 10, 10, 23, 30), now),
        'today at 23:30',
      );
      expect(
        formatNextEpisodeTime(ru, DateTime(2026, 10, 11, 1, 5), now),
        'завтра в 01:05',
      );
    });

    test('counts later days by the date, not the hours', () {
      expect(
        formatNextEpisodeTime(ru, DateTime(2026, 10, 12, 9), now),
        'через 2 дня',
      );
      expect(
        formatNextEpisodeTime(ru, DateTime(2026, 10, 15, 9), now),
        'через 5 дней',
      );
      expect(
        formatNextEpisodeTime(en, DateTime(2026, 10, 31, 9), now),
        'in 21 days',
      );
    });

    test('says nothing once it is due', () {
      expect(formatNextEpisodeTime(en, now, now), isNull);
    });
  });

  test('age ratings print as they are known', () {
    expect(formatAgeRating('pg_13'), 'PG-13');
    expect(formatAgeRating('r_plus'), 'R+');
    expect(formatAgeRating('none'), isNull);
  });
}
