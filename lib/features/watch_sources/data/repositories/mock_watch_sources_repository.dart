import 'package:iris/features/watch_sources/data/datasources/mock_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/mappers/nyaa_watch_source_mapper.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';

class MockWatchSourcesRepository implements WatchSourcesRepository {
  const MockWatchSourcesRepository({required this.dataSource});

  final MockWatchSourcesDataSource dataSource;

  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    final seen = <String>{};
    return [
      for (final title in titles)
        for (final item in await dataSource.fetchSources(title))
          if (seen.add(item.link)) mapNyaaWatchSourceToDomain(item),
    ];
  }
}
