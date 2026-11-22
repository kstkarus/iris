import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/l10n/generated/app_localizations_en.dart';
import 'package:iris/l10n/generated/app_localizations_ru.dart';

void main() {
  const name = 'Sousou no Frieren';
  const russian = 'Провожающая в последний путь Фрирен';
  const english = "Frieren: Beyond Journey's End";
  const titles = AnimeTitles(name: name, russian: russian, english: english);
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  for (final (l10n, language, primary, secondary) in [
    (en, AnimeTitleLanguage.auto, english, name),
    (ru, AnimeTitleLanguage.auto, russian, name),
    (en, AnimeTitleLanguage.russian, russian, name),
    (ru, AnimeTitleLanguage.russian, russian, name),
    (en, AnimeTitleLanguage.romaji, name, english),
    (ru, AnimeTitleLanguage.romaji, name, russian),
    (en, AnimeTitleLanguage.english, english, name),
    (ru, AnimeTitleLanguage.english, english, name),
  ]) {
    test('${language.name} in ${l10n.localeName} shows $primary first', () {
      expect(resolveAnimeTitles(l10n, titles, language), (
        primary: primary,
        secondary: secondary,
      ));
    });
  }

  test('missing translations fall back to romaji alone', () {
    const missing = AnimeTitles(name: ' Mushishi ', russian: '  ');
    for (final l10n in [en, ru]) {
      for (final language in AnimeTitleLanguage.values) {
        expect(resolveAnimeTitles(l10n, missing, language), (
          primary: 'Mushishi',
          secondary: null,
        ));
      }
    }
  });

  test(
    'case and whitespace differences alone do not add a secondary title',
    () {
      const repeated = AnimeTitles(name: 'Death Note', english: ' death note ');
      expect(resolveAnimeTitles(en, repeated, AnimeTitleLanguage.auto), (
        primary: 'death note',
        secondary: null,
      ));
      expect(resolveAnimeTitles(en, repeated, AnimeTitleLanguage.romaji), (
        primary: 'Death Note',
        secondary: null,
      ));
    },
  );

  test('an empty romaji title is left out of the secondary line', () {
    expect(
      resolveAnimeTitles(
        en,
        const AnimeTitles(name: ' ', english: english),
        AnimeTitleLanguage.english,
      ),
      (primary: english, secondary: null),
    );
  });
}
