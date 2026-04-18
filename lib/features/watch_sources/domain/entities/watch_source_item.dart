class WatchSourceItem {
  const WatchSourceItem({
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is WatchSourceItem &&
        other.title == title &&
        other.category == category &&
        other.link == link &&
        other.torrent == torrent &&
        other.magnet == magnet &&
        other.size == size &&
        other.time == time &&
        other.seeders == seeders &&
        other.leechers == leechers &&
        other.downloads == downloads;
  }

  @override
  int get hashCode => Object.hash(
    title,
    category,
    link,
    torrent,
    magnet,
    size,
    time,
    seeders,
    leechers,
    downloads,
  );
}
