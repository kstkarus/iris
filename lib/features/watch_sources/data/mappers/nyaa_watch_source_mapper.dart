import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';

/// Episodes and films only: anime music videos are not something to watch
/// an anime with, and anything outside the anime section slipped past the
/// search filter. An unknown category is kept.
bool isWatchableNyaaCategory(String category) {
  if (category.isEmpty) return true;
  return category.startsWith('Anime - ') &&
      category != 'Anime - Anime Music Video';
}

WatchSourceItem mapNyaaWatchSourceToDomain(NyaaWatchSourceDto source) {
  return WatchSourceItem(
    title: source.title,
    category: source.category,
    link: source.link,
    torrent: source.torrent,
    magnet: source.magnet,
    size: source.size,
    time: source.time,
    seeders: source.seeders,
    leechers: source.leechers,
    downloads: source.downloads,
  );
}
