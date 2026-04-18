class NyaaWatchSourceDto {
  const NyaaWatchSourceDto({
    required this.title,
    required this.category,
    required this.link,
    required this.torrent,
    required this.magnet,
    required this.size,
    required this.time,
    required this.seeders,
    required this.leechers,
    required this.downloads,
  });

  final String title;
  final String category;
  final String link;
  final String torrent;
  final String magnet;
  final String size;
  final String time;
  final int seeders;
  final int leechers;
  final int downloads;

  factory NyaaWatchSourceDto.fromJson(Map<String, dynamic> json) {
    return NyaaWatchSourceDto(
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      torrent: json['torrent']?.toString() ?? '',
      magnet: json['magnet']?.toString() ?? '',
      size: json['size']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      seeders: _parseInt(json['seeders']),
      leechers: _parseInt(json['leechers']),
      downloads: _parseInt(json['downloads']),
    );
  }
}

int _parseInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}
