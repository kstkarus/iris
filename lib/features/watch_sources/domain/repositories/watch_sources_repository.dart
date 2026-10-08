import 'package:iris/features/watch_sources/domain/entities/watch_source_item.dart';

abstract interface class WatchSourcesRepository {
  /// Releases named after any of [titles] (one anime's names: releases use
  /// its romaji, English or other names), each release once.
  Future<List<WatchSourceItem>> fetchSources(List<String> titles);
}
