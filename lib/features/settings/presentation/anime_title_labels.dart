import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

typedef AnimeTitleLabels = ({String primary, String? secondary});

AnimeTitleLabels resolveAnimeTitles(
  AppLocalizations l10n,
  AnimeTitles titles,
  AnimeTitleLanguage language,
) {
  final name = titles.name.trim();
  final localized = switch (language) {
    AnimeTitleLanguage.russian => titles.russian,
    AnimeTitleLanguage.english => titles.english,
    AnimeTitleLanguage.auto || AnimeTitleLanguage.romaji =>
      l10n.localeName.startsWith('ru') ? titles.russian : titles.english,
  }.trim();
  final romajiFirst = language == AnimeTitleLanguage.romaji;
  final primary = romajiFirst || localized.isEmpty ? name : localized;
  final secondary = romajiFirst ? localized : name;
  return (
    primary: primary,
    secondary:
        secondary.isEmpty || secondary.toLowerCase() == primary.toLowerCase()
        ? null
        : secondary,
  );
}

AnimeTitleLanguage watchAnimeTitleLanguage(BuildContext context) =>
    context.select<AppSettingsCubit?, AnimeTitleLanguage>(
      (cubit) => cubit?.state.animeTitleLanguage ?? AnimeTitleLanguage.auto,
    );

AnimeTitleLanguage readAnimeTitleLanguage(BuildContext context) =>
    context.read<AppSettingsCubit?>()?.state.animeTitleLanguage ??
    AnimeTitleLanguage.auto;

AnimeTitleLabels watchAnimeTitleLabels(
  BuildContext context,
  AnimeTitles titles,
) => resolveAnimeTitles(
  AppLocalizations.of(context),
  titles,
  watchAnimeTitleLanguage(context),
);
