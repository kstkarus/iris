import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

/// Whether [files]'s episode numbers belong to the anime itself and can be
/// matched safely against external per-episode data (Shikimori counts, Tenrai
/// episode titles and filler/recap flags).
///
/// Online releases carry the anime's own numbers. Torrent files read numbers
/// from file names, so they match only when the numbered files start at 1 and
/// none repeats: a later season numbered on from the first (13, 14…) or a
/// pack of seasons each from 1 would put metadata on the wrong files.
bool filesUseAnimeNumbers(List<PlayerVideoFile> files) {
  if (files.isEmpty) return false;
  return files.any((file) => file.episodeNumber != null) ||
      _numberedFromOne(files);
}

/// The files of [files] that the user's Shikimori list counts as watched,
/// by index: those numbered 1 to [count], the episodes the list has.
///
/// Specials (12.5) are never counted.
Set<int> filesCountedInList(List<PlayerVideoFile> files, int count) {
  if (count <= 0 || !filesUseAnimeNumbers(files)) return const {};
  return {
    for (final file in files)
      if (file.number case final number? when number >= 1 && number <= count)
        file.index,
  };
}

/// Maps [episodes] (keyed by MAL/Shikimori episode number) onto [files] by
/// `file.index`, only when [files] carry the anime's own episode numbers.
Map<int, EpisodeMetadata> episodeMetadataForFiles(
  List<PlayerVideoFile> files,
  Map<int, EpisodeMetadata> episodes,
) {
  if (episodes.isEmpty || !filesUseAnimeNumbers(files)) return const {};
  return {
    for (final file in files)
      if (file.number case final number?) file.index: ?episodes[number],
  };
}

/// The highest whole episode number in [files] when they use the anime's own
/// numbering; null otherwise.
int? maxAnimeEpisodeNumber(List<PlayerVideoFile> files) {
  if (!filesUseAnimeNumbers(files)) return null;
  int? highest;
  for (final file in files) {
    final number = file.number;
    if (number != null && (highest == null || number > highest)) {
      highest = number;
    }
  }
  return highest;
}

bool _numberedFromOne(List<PlayerVideoFile> files) {
  final numbers = <int>{};
  for (final file in files) {
    final number = file.number;
    if (number == null) continue;
    if (!numbers.add(number)) return false;
  }
  return numbers.isNotEmpty && numbers.reduce((a, b) => a < b ? a : b) == 1;
}
