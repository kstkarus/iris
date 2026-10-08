import 'package:intl/intl.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

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
    case 'special':
      return l10n.animeKindSpecial;
    case 'tv_special':
      return l10n.animeKindTvSpecial;
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
  return l10n.animeScoreLabel(formatAnimeScoreValue(l10n, score));
}

/// The bare number, for places that already say it is a score.
String formatAnimeScoreValue(AppLocalizations l10n, double score) {
  return NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: 2,
  ).format(score);
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

/// The total for finished titles (the catalog reports 0 aired episodes for
/// some of them), aired/total while a title is airing.
String? formatEpisodes(
  AppLocalizations l10n,
  String status,
  int episodes,
  int episodesAired,
) {
  final numberFormat = NumberFormat.decimalPattern(l10n.localeName);
  if (episodes > 0 && (status == 'released' || episodesAired >= episodes)) {
    return l10n.animeEpisodeCount(numberFormat.format(episodes), episodes);
  }
  if (episodes > 0) {
    return formatEpisodeProgress(l10n, episodesAired, episodes);
  }
  if (episodesAired > 0) {
    return l10n.animeEpisodeCount(
      numberFormat.format(episodesAired),
      episodesAired,
    );
  }
  return null;
}

/// Shows as much of the date as is known: the year, the month and year, or
/// the full date (see `incompleteIsoDate`).
String formatAiredOn(AppLocalizations l10n, String rawDate) {
  final parts = rawDate.split('-').map(int.tryParse).toList();
  if (parts.isEmpty || parts.length > 3 || parts.contains(null)) {
    return rawDate;
  }
  final [year!, ...rest] = parts;
  return switch (rest) {
    [] => '$year',
    [final month!] => DateFormat.yMMMM(
      l10n.localeName,
    ).format(DateTime(year, month)),
    [final month!, final day!] => DateFormat.yMMMd(
      l10n.localeName,
    ).format(DateTime(year, month, day)),
    _ => rawDate,
  };
}
