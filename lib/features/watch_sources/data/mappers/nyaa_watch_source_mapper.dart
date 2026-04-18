import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';

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
