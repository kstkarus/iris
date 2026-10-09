import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';

abstract interface class OnlineSourcesRepository {
  /// Releases of the anime with [shikimoriId], looked up under any of its
  /// [titles]. Only releases that name that id are kept: a release is never
  /// matched by its name alone.
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  });

  /// The release [id] of [provider], with its episodes; a release found
  /// earlier, opened again from the file picker or watch history.
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  });

  /// One episode's streams, best quality first, issued afresh. Empty when
  /// the provider has none for it (e.g. blocked in the region).
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  });
}
