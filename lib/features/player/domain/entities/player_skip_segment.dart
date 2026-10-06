/// What a skippable part of an episode is.
enum PlayerSkipKind { opening, ending, recap }

/// A part of a file the viewer may want to skip.
class PlayerSkipSegment {
  const PlayerSkipSegment({
    required this.kind,
    required this.start,
    required this.end,
  });

  final PlayerSkipKind kind;
  final Duration start;
  final Duration end;

  /// Inside the segment, short of its last second (skipping that is
  /// pointless).
  bool contains(Duration position) {
    return position >= start && position < end - const Duration(seconds: 1);
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerSkipSegment &&
        other.kind == kind &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(kind, start, end);

  @override
  String toString() => 'PlayerSkipSegment($kind, $start - $end)';
}
