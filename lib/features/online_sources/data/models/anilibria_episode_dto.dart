/// An episode as AniLibria's API gives it; the links may be null, e.g. for
/// a release blocked in the region.
class AnilibriaEpisodeDto {
  const AnilibriaEpisodeDto({
    required this.id,
    required this.ordinal,
    required this.sortOrder,
    this.name,
    this.durationSeconds,
    this.hls480,
    this.hls720,
    this.hls1080,
  });

  final String id;
  final num ordinal;
  final int sortOrder;
  final String? name;
  final int? durationSeconds;
  final String? hls480;
  final String? hls720;
  final String? hls1080;

  factory AnilibriaEpisodeDto.fromJson(Map<String, dynamic> json) {
    final ordinal = json['ordinal'];
    return AnilibriaEpisodeDto(
      id: json['id']?.toString() ?? '',
      ordinal: ordinal is num ? ordinal : num.tryParse('$ordinal') ?? 0,
      sortOrder: _int(json['sort_order']) ?? 0,
      name: _text(json['name']),
      durationSeconds: _int(json['duration']),
      hls480: _text(json['hls_480']),
      hls720: _text(json['hls_720']),
      hls1080: _text(json['hls_1080']),
    );
  }
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
