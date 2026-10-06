import 'package:iris/features/player/data/models/aniskip_skip_time_dto.dart';
import 'package:iris/features/player/domain/entities/player_skip_segment.dart';

/// Null for unknown types and empty intervals.
PlayerSkipSegment? mapAniSkipSkipTime(AniSkipSkipTimeDto dto) {
  final kind = switch (dto.skipType) {
    'op' || 'mixed-op' => PlayerSkipKind.opening,
    'ed' || 'mixed-ed' => PlayerSkipKind.ending,
    'recap' => PlayerSkipKind.recap,
    _ => null,
  };
  final start = _duration(dto.startTime);
  final end = _duration(dto.endTime);
  if (kind == null || start < Duration.zero || end <= start) return null;
  return PlayerSkipSegment(kind: kind, start: start, end: end);
}

Duration _duration(double seconds) {
  return Duration(milliseconds: (seconds * 1000).round());
}
