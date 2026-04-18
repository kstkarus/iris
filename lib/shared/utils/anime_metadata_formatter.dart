import 'package:intl/intl.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

String formatAnimeKindAndStatus(
  AppLocalizations l10n,
  String kind,
  String status,
) {
  return '${formatAnimeKind(l10n, kind)} / ${formatAnimeStatus(l10n, status)}';
}

String formatAnimeKind(AppLocalizations l10n, String kind) {
  switch (kind) {
    case 'tv':
      return l10n.animeKindTv;
    case 'movie':
      return l10n.animeKindMovie;
    case 'ova':
      return l10n.animeKindOva;
    case 'ona':
      return l10n.animeKindOna;
    default:
      return kind.toUpperCase();
  }
}

String formatAnimeStatus(AppLocalizations l10n, String status) {
  switch (status) {
    case 'released':
      return l10n.animeStatusReleased;
    case 'ongoing':
      return l10n.animeStatusOngoing;
    case 'anons':
      return l10n.animeStatusAnnounced;
    default:
      return status;
  }
}

String formatAnimeScore(AppLocalizations l10n, double score) {
  final value = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: 2,
  ).format(score);

  return l10n.animeScoreLabel(value);
}

String formatEpisodeProgress(
  AppLocalizations l10n,
  int airedEpisodes,
  int totalEpisodes,
) {
  final numberFormat = NumberFormat.decimalPattern(l10n.localeName);

  return l10n.animeEpisodeProgress(
    numberFormat.format(airedEpisodes),
    numberFormat.format(totalEpisodes),
    totalEpisodes,
  );
}

String formatAiredOn(AppLocalizations l10n, String rawDate) {
  final parsedDate = DateTime.tryParse(rawDate);

  if (parsedDate == null) {
    return rawDate;
  }

  return DateFormat.yMMMd(l10n.localeName).format(parsedDate);
}
