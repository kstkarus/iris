import 'package:iris/shared/utils/equality.dart';

enum OnlineStreamFormat { hls, dash, mp4 }

/// A playable link to one episode in one quality. It expires; resolve it
/// again rather than keep it.
class OnlineStream {
  const OnlineStream({
    required this.url,
    required this.quality,
    required this.format,
    this.httpHeaders = const {},
  });

  final String url;

  /// The picture's height, e.g. 720.
  final int quality;
  final OnlineStreamFormat format;

  /// What the server wants with every request, such as a Referer.
  final Map<String, String> httpHeaders;

  @override
  bool operator ==(Object other) {
    return other is OnlineStream &&
        other.url == url &&
        other.quality == quality &&
        other.format == format &&
        sameMap(other.httpHeaders, httpHeaders);
  }

  @override
  int get hashCode => Object.hash(
    url,
    quality,
    format,
    Object.hashAllUnordered(
      httpHeaders.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}
