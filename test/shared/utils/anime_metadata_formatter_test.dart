import 'package:flutter_test/flutter_test.dart';

import 'package:iris/l10n/generated/app_localizations_en.dart';
import 'package:iris/l10n/generated/app_localizations_ru.dart';
import 'package:iris/shared/utils/anime_metadata_formatter.dart';

void main() {
  final en = AppLocalizationsEn();

  test('shows the total for released titles without aired episodes', () {
    expect(formatEpisodes(en, 'released', 37, 0), '37 episodes');
    expect(formatEpisodes(AppLocalizationsRu(), 'released', 21, 0), '21 серия');
  });
}
