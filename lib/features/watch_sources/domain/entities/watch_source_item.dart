class WatchSourceItem {
  const WatchSourceItem({
    required this.title,
    required this.magnet,
    required this.size,
    required this.time,
    required this.seeders,
    required this.downloads,
  });

  final String title;
  final String magnet;
  final String size;
  final String time;
  final int seeders;
  final int downloads;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WatchSourceItem &&
        other.title == title &&
        other.magnet == magnet &&
        other.size == size &&
        other.time == time &&
        other.seeders == seeders &&
        other.downloads == downloads;
  }

  @override
  int get hashCode =>
      Object.hash(title, magnet, size, time, seeders, downloads);
}
