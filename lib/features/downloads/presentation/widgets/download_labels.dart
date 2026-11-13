import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';

String downloadName(AppLocalizations l10n, DownloadItem item) {
  final title = item.animeTitle.trim().isNotEmpty
      ? item.animeTitle.trim()
      : item.sourceTitle.trim().isNotEmpty
      ? item.sourceTitle.trim()
      : fileDisplayName(item.fileName).trim();
  final episode = downloadEpisode(l10n, item);
  return title.isEmpty || title.toLowerCase() == episode.toLowerCase()
      ? episode
      : '$title, $episode';
}

String downloadSemanticName(AppLocalizations l10n, DownloadItem item) {
  final name = downloadName(l10n, item);
  final release =
      item.animeTitle.trim().isNotEmpty && item.sourceTitle.trim().isNotEmpty
      ? downloadSourceLabel(l10n, item)
      : '';
  return [
    name,
    if (release.isNotEmpty) release,
    if (item.videoHeight case final height?) l10n.onlineQualityHeight(height),
  ].join(', ');
}

/// The episode read from the file name, or the file's own name.
String downloadEpisode(AppLocalizations l10n, DownloadItem item) {
  final number = episodeNumberFromFileName(item.fileName);
  return number == null
      ? fileDisplayName(item.fileName)
      : l10n.downloadEpisodeLabel(number.toString().padLeft(2, '0'));
}

String downloadSourceLabel(
  AppLocalizations l10n,
  DownloadItem item, {
  int? videoHeight,
}) {
  final name = item.animeTitle;
  var label = name.isEmpty
      ? item.sourceTitle
      : item.sourceTitle
            .replaceAll(RegExp(RegExp.escape(name), caseSensitive: false), '')
            .trim();
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
  return [
    label.toUpperCase(),
    if (videoHeight != null) l10n.onlineQualityHeight(videoHeight),
  ].join(' · ');
}
