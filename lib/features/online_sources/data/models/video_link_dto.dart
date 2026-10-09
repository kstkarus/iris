/// A playable link a video player's page or API gave out.
class VideoLinkDto {
  const VideoLinkDto({
    required this.url,
    required this.quality,
    required this.kind,
  });

  final String url;

  /// The picture's height, e.g. 720.
  final int quality;
  final VideoLinkKind kind;
}

enum VideoLinkKind { hls, dash, mp4 }
