import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';

abstract interface class WatchSourcesRepository {
  Future<List<WatchSourceItem>> fetchSources(String animeEnglishTitle);
}
