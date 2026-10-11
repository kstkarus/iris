import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/shared/utils/equality.dart';

/// An anime as one provider has it, in one voice-over, with its episodes in
/// playback order.
class OnlineRelease {
  const OnlineRelease({
    required this.provider,
    required this.id,
    required this.dub,
    required this.episodes,
    this.bestQuality,
  });

  final OnlineProvider provider;

  /// The provider's id of the release.
  final String id;

  /// Who voiced it, e.g. "AniLibria".
  final String dub;
  final List<OnlineEpisode> episodes;

  /// The tallest picture any episode has, e.g. 1080; null when unknown.
  final int? bestQuality;

  @override
  bool operator ==(Object other) {
    return other is OnlineRelease &&
        other.provider == provider &&
        other.id == id &&
        other.dub == dub &&
        other.bestQuality == bestQuality &&
        sameList(other.episodes, episodes);
  }

  @override
  int get hashCode =>
      Object.hash(provider, id, dub, bestQuality, Object.hashAll(episodes));
}
