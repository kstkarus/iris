import 'package:flutter/foundation.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/utils/release_title.dart';

/// The immersive player's titles for [source]: the anime (or release) over
/// the episode, and the episode's place in the release.
PlayerChrome playerChromeFor(
  AppLocalizations l10n,
  AnimePlayerSource source, {
  required VoidCallback onBack,
  PlayerNotice? notice,
  PlayerEpisodesBuilder? episodes,
}) {
  final release = source.sourceTitle.trim();
  final anime = source.animeTitle.trim();
  // Saved torrents carry their release name as the anime title too.
  final overline = anime.isNotEmpty && anime != release
      ? anime
      : releaseDisplayTitle(release);
  final episode = source.episodeNumber;
  final count = source.files.length;
  final position = source.files.indexWhere(
    (file) => file.index == source.fileIndex,
  );
  final inRelease = count > 1 && position >= 0;
  // Where the episode number is the file's place, the place adds only
  // the total: "Episode 20 of 37" instead of a line repeating the 20.
  final placeIsNumber = inRelease && episode == position + 1;
  final details = inRelease && !placeIsNumber
      ? l10n.playerEpisodePosition(position + 1, count)
      : null;
  final episodesCaption = [
    if (release.isNotEmpty) release,
    l10n.animeEpisodeCount('$count', count),
  ].join(' · ');

  return PlayerChrome(
    title: episode == null
        ? fileDisplayName(source.fileName)
        : l10n.playerEpisodeNumber(episode),
    titleDetail: placeIsNumber ? l10n.playerEpisodeOfTotal(count) : null,
    overline: overline,
    details: details,
    episodesCaption: episodesCaption,
    onBack: onBack,
    notice: notice,
    episodes: episodes,
  );
}
