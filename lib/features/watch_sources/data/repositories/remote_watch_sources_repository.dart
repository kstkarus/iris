import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/mappers/nyaa_watch_source_mapper.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';

class RemoteWatchSourcesRepository implements WatchSourcesRepository {
  const RemoteWatchSourcesRepository({required this.dataSource});

  final RemoteWatchSourcesDataSource dataSource;

  @override
  Future<List<WatchSourceItem>> fetchSources(String animeEnglishTitle) async {
    final items = await dataSource.fetchSources(animeEnglishTitle);
    return items
        .where((item) => isWatchableNyaaCategory(item.category))
        .map(mapNyaaWatchSourceToDomain)
        .toList();
  }
}
