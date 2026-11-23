import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';

String downloadName(
  AppLocalizations l10n,
  DownloadItem item, {
  AnimeTitleLanguage titleLanguage = AnimeTitleLanguage.auto,
}) {
  final anime = resolveAnimeTitles(
    l10n,
    item.animeTitles,
    titleLanguage,
  ).primary;
  final source = item.sourceTitle.trim();
  final title = anime.isNotEmpty
      ? anime
      : source.isNotEmpty
      ? source
      : fileDisplayName(item.fileName).trim();
  final episode = downloadEpisode(l10n, item);
  return title.isEmpty || title.toLowerCase() == episode.toLowerCase()
      ? episode
      : '$title, $episode';
}

String downloadSemanticName(
  AppLocalizations l10n,
  DownloadItem item, {
  AnimeTitleLanguage titleLanguage = AnimeTitleLanguage.auto,
}) {
  final name = downloadName(l10n, item, titleLanguage: titleLanguage);
  final facts = downloadSourceFacts(item);
  final separateRelease =
      item.sourceTitle.trim().isNotEmpty &&
      resolveAnimeTitles(
        l10n,
        item.animeTitles,
        titleLanguage,
      ).primary.isNotEmpty;
  return [
    name,
    if (separateRelease && facts.source.isNotEmpty) facts.source,
    if (separateRelease || item.videoHeight != null)
      if (facts.videoHeight case final height?)
        l10n.onlineQualityHeight(height),
  ].join(', ');
}

num? downloadEpisodeNumber(DownloadItem item) => item.isOnline
    ? parseOnlineEpisodeFileName(item.fileName)?.number
    : episodeNumberFromFileName(item.fileName);

// Online sizes are estimates until the file is complete.
double downloadDisplayProgress(DownloadItem item) =>
    item.isOnline ? item.progressUntilCompleted : item.progress;

/// The supplied online number, a torrent's recognised episode, or the file name.
String downloadEpisode(AppLocalizations l10n, DownloadItem item) {
  final number = downloadEpisodeNumber(item);
  return number == null
      ? item.isOnline
            ? item.fileName
            : fileDisplayName(item.fileName)
      : l10n.downloadEpisodeLabel(number.toString().padLeft(2, '0'));
}

String downloadSourceLabel(DownloadItem item) {
  final titles =
      [
          item.animeTitle.trim(),
          item.animeRussian.trim(),
          item.animeEnglish.trim(),
        ]
        ..removeWhere((title) => title.isEmpty)
        ..sort((a, b) => b.length.compareTo(a.length));
  var label = item.sourceTitle;
  if (titles.isNotEmpty) {
    final variants = titles.map(RegExp.escape).join('|');
    label = label.replaceAll(
      RegExp(
        r'(?<![\p{L}\p{N}])(?:' + variants + r')(?![\p{L}\p{N}])',
        caseSensitive: false,
        unicode: true,
      ),
      '',
    );
  }
  label = label
      .replaceAll(RegExp(r'[\[\]()]'), '')
      .replaceAll(RegExp(r'^\s*[·|—-]+|[·|—-]+\s*$'), '')
      .trim();
  if (label.isEmpty) label = item.sourceTitle;
  label = label
      .replaceAll(
        RegExp(
          r'\.(?:mp4|mkv|avi|mov|m4v|webm|ts|flv|wmv)$',
          caseSensitive: false,
        ),
        '',
      )
      .trim();
  return label;
}

/// A title's text is not a measurement of the file's resolution.
({String source, int? videoHeight}) downloadSourceFacts(DownloadItem item) {
  final reported = item.videoHeight;
  return (
    source: downloadSourceLabel(item),
    videoHeight: reported != null && reported > 0 ? reported : null,
  );
}

/// Drops a redundant resolution tag (e.g. `1080p`) from [source] when an
/// identical [shownVideoHeight] badge is rendered right beside it.
String displayReleaseLabel(String source, {int? shownVideoHeight}) {
  if (shownVideoHeight == null || shownVideoHeight <= 0) return source;
  final stripped = source
      .replaceAll(
        RegExp(
          '(?<![\\p{L}\\p{N}])${shownVideoHeight}p(?![\\p{L}\\p{N}])',
          caseSensitive: false,
          unicode: true,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'^\s*[·|—-]+|[·|—-]+\s*$'), '')
      .trim();
  return stripped.isEmpty ? source : stripped;
}
