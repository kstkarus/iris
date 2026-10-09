import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';

/// The anime looked up on every video server at once, shown as each
/// answers: a slow server does not hold back what a fast one found.
abstract interface class OnlineReleasesSearch {
  /// Every release found so far, each time a server answers with more,
  /// matched as [OnlineSourcesRepository.findReleases] matches. Never
  /// empty; the stream ends when the last server has answered. It fails
  /// only when nothing was found and a server failed.
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  });
}
