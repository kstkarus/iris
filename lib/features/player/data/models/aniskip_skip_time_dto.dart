class AniSkipSkipTimeDto {
  const AniSkipSkipTimeDto({
    required this.skipType,
    required this.startTime,
    required this.endTime,
  });

  factory AniSkipSkipTimeDto.fromJson(Map<String, dynamic> json) {
    final interval = json['interval'];
    if (interval is! Map<String, dynamic>) {
      throw const FormatException('AniSkip result without an interval.');
    }
    return AniSkipSkipTimeDto(
      skipType: json['skipType']?.toString() ?? '',
      startTime: _seconds(interval['startTime']),
      endTime: _seconds(interval['endTime']),
    );
  }

  final String skipType;

  /// Seconds from the start of the episode.
  final double startTime;
  final double endTime;
}

double _seconds(Object? value) {
  if (value is num) return value.toDouble();
  throw const FormatException('AniSkip time is not a number.');
}
