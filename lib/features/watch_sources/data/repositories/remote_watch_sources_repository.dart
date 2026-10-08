import 'package:iris/features/watch_sources/data/datasources/remote_watch_sources_data_source.dart';
import 'package:iris/features/watch_sources/data/mappers/nyaa_watch_source_mapper.dart';
import 'package:iris/features/watch_sources/data/models/nyaa_watch_source_dto.dart';
import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';
import 'package:iris/features/watch_sources/domain/repositories/watch_sources_repository.dart';

class RemoteWatchSourcesRepository implements WatchSourcesRepository {
  const RemoteWatchSourcesRepository({required this.dataSource});

  final RemoteWatchSourcesDataSource dataSource;

  /// One search per title, together: nyaa has no "or", and a release is
  /// found only by the name its group used. A title that fails does not
  /// hide what the others found. Only when nothing was found and a search
  /// failed is the first failure thrown, so it reads as an error, not as
  /// "no sources".
  @override
  Future<List<WatchSourceItem>> fetchSources(List<String> titles) async {
    final results = await Future.wait(
      titles.map((title) async {
        try {
          return (items: await dataSource.fetchSources(title), error: null);
        } on Object catch (error) {
          return (items: const <NyaaWatchSourceDto>[], error: error);
        }
      }),
    );
    final failure = results.where((result) => result.error != null);

    final seen = <String>{};
    final items = [
      for (final result in results)
        for (final item in result.items)
          if (isWatchableNyaaCategory(item.category) &&
              seen.add(item.link.isEmpty ? item.magnet : item.link))
            mapNyaaWatchSourceToDomain(item),
    ];
    if (items.isEmpty && failure.isNotEmpty) {
      throw failure.first.error!;
    }
    return items;
  }
}
