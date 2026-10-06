import 'package:iris/features/player/domain/entities/player_skip_segment.dart';

/// A chapter of a video file.
class PlayerChapter {
  const PlayerChapter({required this.title, required this.start});

  final String title;
  final Duration start;
}

final _opening = RegExp(
  r'^\s*(op\d*\b|opening|intro\b|introduction|オープニング|опенинг)',
  caseSensitive: false,
);
final _ending = RegExp(
  r'^\s*(ed\d*\b|ending|outro|credits|end\s*credits|エンディング|эндинг)',
  caseSensitive: false,
);
final _recap = RegExp(r'^\s*(recap|previously|あらすじ)', caseSensitive: false);

/// Openings, endings and recaps named by a file's chapters (common in BD
/// rips). A chapter lasts until the next one starts.
List<PlayerSkipSegment> skipSegmentsFromChapters(
  List<PlayerChapter> chapters,
  Duration duration,
) {
  final sorted = [...chapters]..sort((a, b) => a.start.compareTo(b.start));
  final segments = <PlayerSkipSegment>[];
  for (var i = 0; i < sorted.length; i++) {
    final kind = _kindOf(sorted[i].title);
    if (kind == null) continue;
    final start = sorted[i].start;
    final end = i + 1 < sorted.length ? sorted[i + 1].start : duration;
    if (end <= start) continue;
    segments.add(PlayerSkipSegment(kind: kind, start: start, end: end));
  }
  return segments;
}

PlayerSkipKind? _kindOf(String title) {
  if (_opening.hasMatch(title)) return PlayerSkipKind.opening;
  if (_ending.hasMatch(title)) return PlayerSkipKind.ending;
  if (_recap.hasMatch(title)) return PlayerSkipKind.recap;
  return null;
}
