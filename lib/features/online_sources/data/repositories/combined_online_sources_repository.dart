import 'dart:async';

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';

/// Every provider at once, in [providers]' order. A dub two providers have
/// is shown once: the copy with more episodes, and on a tie the earlier
/// provider's (AniLibria's own release over yummy_anime's copy of it), so
/// a release cut short by a block does not hide a whole one.
class CombinedOnlineSourcesRepository
    implements OnlineSourcesRepository, OnlineReleasesSearch {
  const CombinedOnlineSourcesRepository({required this.providers});

  final Map<OnlineProvider, OnlineSourcesRepository> providers;

  /// A provider that fails does not hide what the others found; only when
  /// nothing was found and a provider failed is the failure thrown.
  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    final found = await watchReleases(
      shikimoriId: shikimoriId,
      titles: titles,
    ).toList();
    return found.isEmpty ? const [] : found.last;
  }

  /// Each answer is merged in [providers]' order, not in the order the
  /// answers come, so the result does not depend on which site is faster.
  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) {
    final repositories = providers.values.toList(growable: false);
    final answers = List<List<OnlineRelease>>.filled(
      repositories.length,
      const [],
    );
    Object? failure;
    var pending = repositories.length;
    late final StreamController<List<OnlineRelease>> controller;

    void answered() {
      if (--pending > 0) return;
      if (failure case final error? when answers.every((a) => a.isEmpty)) {
        controller.addError(error);
      }
      unawaited(controller.close());
    }

    controller = StreamController(
      onListen: () {
        if (repositories.isEmpty) {
          unawaited(controller.close());
          return;
        }
        for (final (index, repository) in repositories.indexed) {
          unawaited(
            Future.sync(
                  () => repository.findReleases(
                    shikimoriId: shikimoriId,
                    titles: titles,
                  ),
                )
                .then(
                  (releases) {
                    answers[index] = releases;
                    if (releases.isNotEmpty) controller.add(_merge(answers));
                  },
                  onError: (Object error) {
                    failure ??= error;
                  },
                )
                .whenComplete(answered),
          );
        }
      },
    );
    return controller.stream;
  }

  static List<OnlineRelease> _merge(List<List<OnlineRelease>> answers) {
    final byDub = <String, OnlineRelease>{};
    for (final releases in answers) {
      for (final release in releases) {
        final dub = release.dub.trim().toLowerCase();
        final kept = byDub[dub];
        if (kept == null || release.episodes.length > kept.episodes.length) {
          byDub[dub] = release;
        }
      }
    }
    // In the order the dubs were first found.
    return byDub.values.toList(growable: false);
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
