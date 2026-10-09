import 'package:iris/features/online_sources/data/datasources/anilibria_data_source.dart';
import 'package:iris/features/online_sources/data/mappers/anilibria_mapper.dart';
import 'package:iris/features/online_sources/data/models/anilibria_release_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// Follows anicli-api 0.12.0, `anicli_api/source/anilibria.py`.
class AnilibriaOnlineSourcesRepository implements OnlineSourcesRepository {
  const AnilibriaOnlineSourcesRepository({required this.dataSource});

  final AnilibriaDataSource dataSource;

  /// One search per title, together, as AniLibria finds a release by its
  /// Russian or its romaji name. A title that fails does not hide what the
  /// others found; only when no release matched and a search failed is the
  /// failure thrown, so it reads as an error rather than "not there".
  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    final id = int.tryParse(shikimoriId);
    if (id == null) return const [];
    final queries = {
      for (final title in titles)
        if (title.trim().isNotEmpty) title.trim(),
    };
    final results = await Future.wait(
      queries.map((query) async {
        try {
          return (items: await dataSource.search(query), error: null);
        } on Object catch (error) {
          return (items: const <AnilibriaReleaseDto>[], error: error);
        }
      }),
    );

    final matching = <int>{
      for (final result in results)
        for (final item in result.items)
          if (item.shikimoriId == id && item.id != 0) item.id,
    };
    if (matching.isEmpty) {
      for (final result in results) {
        if (result.error case final error?) throw error;
      }
      return const [];
    }
    final releases = await Future.wait(matching.map(dataSource.release));
    return [
      for (final release in releases.map(mapAnilibriaRelease))
        // A release with nothing to play would hide another site's copy.
        if (release.episodes.isNotEmpty) release,
    ];
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    final releaseId = int.tryParse(id);
    if (releaseId == null) {
      throw ResourceNotFoundException('No AniLibria release $id.');
    }
    return mapAnilibriaRelease(await dataSource.release(releaseId));
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    return mapAnilibriaStreams(await dataSource.episode(episodeId));
  }
}
