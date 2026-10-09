import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// The offline demo has no video servers: nothing is found online.
class MockOnlineSourcesRepository
    implements OnlineSourcesRepository, OnlineReleasesSearch {
  const MockOnlineSourcesRepository();

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async => const [];

  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => const Stream.empty();

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async => throw ResourceNotFoundException('No online release $id.');

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async => const [];
}
