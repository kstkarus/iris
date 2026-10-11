enum OnlineStreamFormat { hls, dash, mp4 }

/// A playable link to one episode in one quality. It expires; resolve it
/// again rather than keep it.
class OnlineStream {
  const OnlineStream({
    required this.url,
    required this.quality,
    required this.format,
  });

  final String url;

  /// The picture's height, e.g. 720.
  final int quality;
  final OnlineStreamFormat format;

  @override
  bool operator ==(Object other) {
    return other is OnlineStream &&
        other.url == url &&
        other.quality == quality &&
        other.format == format;
  }

  @override
  int get hashCode => Object.hash(url, quality, format);
}
