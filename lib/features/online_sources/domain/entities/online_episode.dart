/// One episode of an [OnlineRelease]. Its streams are resolved separately,
/// right before playing: the links expire.
class OnlineEpisode {
  const OnlineEpisode({
    required this.id,
    required this.number,
    this.title = '',
    this.duration,
  });

  /// The provider's id, to resolve the episode's streams with.
  final String id;

  /// The episode's number in the release; specials may be fractional.
  final num number;

  /// Empty when the provider gives none.
  final String title;
  final Duration? duration;

  @override
  bool operator ==(Object other) {
    return other is OnlineEpisode &&
        other.id == id &&
        other.number == number &&
        other.title == title &&
        other.duration == duration;
  }

  @override
  int get hashCode => Object.hash(id, number, title, duration);
}
