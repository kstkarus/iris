import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/player_chapter_skip_segments.dart';

/// A stretch of a file's timeline between two cuts.
class PlayerTimelinePart {
  const PlayerTimelinePart({
    required this.start,
    required this.end,
    this.title,
    this.kind,
  });

  final Duration start;
  final Duration end;

  /// The chapter's own name, when the file gives one.
  final String? title;

  /// An opening, ending or recap, by the chapter's name or the lookup.
  final PlayerSkipKind? kind;

  bool contains(Duration position) => position >= start && position < end;

  @override
  bool operator ==(Object other) {
    return other is PlayerTimelinePart &&
        other.start == start &&
        other.end == end &&
        other.title == title &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(start, end, title, kind);

  @override
  String toString() => 'PlayerTimelinePart($start - $end, $title, $kind)';
}

/// The file's timeline cut into parts: by its chapters when it has two or
/// more, otherwise by the looked-up openings, endings and recaps with the
/// stretches around them. Empty when there is nothing to cut by, or the
/// length is not known yet.
List<PlayerTimelinePart> timelineParts({
  required List<PlayerChapter> chapters,
  required List<PlayerSkipSegment> segments,
  required Duration duration,
}) {
  if (duration <= Duration.zero) return const [];
  final parts = chapters.length >= 2
      ? _chapterParts(chapters, duration)
      : _segmentParts(segments, duration);
  return parts.length >= 2 ? List.unmodifiable(parts) : const [];
}

List<PlayerTimelinePart> _chapterParts(
  List<PlayerChapter> chapters,
  Duration duration,
) {
  final sorted = [...chapters]..sort((a, b) => a.start.compareTo(b.start));
  final parts = <PlayerTimelinePart>[];
  for (var i = 0; i < sorted.length; i++) {
    final start = _within(sorted[i].start, duration);
    final end = i + 1 < sorted.length
        ? _within(sorted[i + 1].start, duration)
        : duration;
    if (end <= start) continue;
    final title = sorted[i].title.trim();
    parts.add(
      PlayerTimelinePart(
        // The first part runs from the start, whatever the file says.
        start: parts.isEmpty ? Duration.zero : start,
        end: end,
        title: title.isEmpty ? null : title,
        kind: skipKindOfChapter(title),
      ),
    );
  }
  return parts;
}

List<PlayerTimelinePart> _segmentParts(
  List<PlayerSkipSegment> segments,
  Duration duration,
) {
  final sorted = [...segments]..sort((a, b) => a.start.compareTo(b.start));
  final parts = <PlayerTimelinePart>[];
  var cursor = Duration.zero;
  for (final segment in sorted) {
    // Overlapping lookups: the later one starts where the earlier ends.
    final start = _within(segment.start, duration);
    final end = _within(segment.end, duration);
    final from = start < cursor ? cursor : start;
    if (end <= from) continue;
    if (from > cursor) {
      parts.add(PlayerTimelinePart(start: cursor, end: from));
    }
    parts.add(PlayerTimelinePart(start: from, end: end, kind: segment.kind));
    cursor = end;
  }
  if (parts.isNotEmpty && cursor < duration) {
    parts.add(PlayerTimelinePart(start: cursor, end: duration));
  }
  return parts;
}

Duration _within(Duration value, Duration duration) {
  if (value < Duration.zero) return Duration.zero;
  return value > duration ? duration : value;
}
