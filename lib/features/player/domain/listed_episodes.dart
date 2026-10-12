import 'package:iris/features/player/domain/entities/player_video_file.dart';

/// The files of [files] that the user's Shikimori list counts as watched,
/// by index: those numbered 1 to [count], the episodes the list has.
///
/// The list keeps only a count of the anime's episodes, so it is matched
/// by number only where the numbers are the anime's own. An online
/// release's are. A torrent's are read from file names, so they count only
/// when the numbered files start at 1 and none repeats: a later season
/// numbered on from the first (13, 14…) or a pack of seasons each from 1
/// would put the marks on the wrong files. Specials (12.5) are never
/// counted.
Set<int> filesCountedInList(List<PlayerVideoFile> files, int count) {
  if (count <= 0 || files.isEmpty) return const {};
  final given = files.any((file) => file.episodeNumber != null);
  if (!given && !_numberedFromOne(files)) return const {};
  return {
    for (final file in files)
      if (file.number case final number? when number >= 1 && number <= count)
        file.index,
  };
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
