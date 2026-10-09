import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// Every provider at once, in [providers]' order. A dub two providers have
/// is shown once: the copy with more episodes, and on a tie the earlier
/// provider's (AniLibria's own release over yummy_anime's copy of it), so
/// a release cut short by a block does not hide a whole one.
class CombinedOnlineSourcesRepository implements OnlineSourcesRepository {
  const CombinedOnlineSourcesRepository({required this.providers});

  final Map<OnlineProvider, OnlineSourcesRepository> providers;

  /// A provider that fails does not hide what the others found; only when
  /// nothing was found and a provider failed is the failure thrown.
  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    final results = await Future.wait(
      providers.values.map((repository) async {
        try {
          final releases = await repository.findReleases(
            shikimoriId: shikimoriId,
            titles: titles,
          );
          return (releases: releases, error: null);
        } on Object catch (error) {
          return (releases: const <OnlineRelease>[], error: error);
        }
      }),
    );
    final byDub = <String, OnlineRelease>{};
    for (final result in results) {
      for (final release in result.releases) {
        final dub = release.dub.trim().toLowerCase();
        final kept = byDub[dub];
        if (kept == null || release.episodes.length > kept.episodes.length) {
          byDub[dub] = release;
        }
      }
    }
    // In the order the dubs were first found.
    final releases = byDub.values.toList();
    if (releases.isEmpty) {
      for (final result in results) {
        if (result.error case final error?) throw error;
      }
    }
    return releases;
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    return _provider(provider).fetchRelease(provider: provider, id: id);
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    return _provider(
      provider,
    ).resolveStreams(provider: provider, episodeId: episodeId);
  }

  OnlineSourcesRepository _provider(OnlineProvider provider) {
    final repository = providers[provider];
    if (repository == null) {
      throw ResourceNotFoundException('No ${provider.name} source is set up.');
    }
    return repository;
  }
}
