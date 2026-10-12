import 'package:iris/shared/utils/equality.dart';

class PlayerSession {
  const PlayerSession({
    required this.sessionId,
    required this.streamUrl,
    this.qualities = const [],
    this.quality,
  });

  final String sessionId;
  final String streamUrl;

  /// The picture heights the file is offered in, tallest first; empty when
  /// there is no choice (a torrent, a download).
  final List<int> qualities;

  /// The height [streamUrl] plays in, when it is one of [qualities].
  final int? quality;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerSession &&
        other.sessionId == sessionId &&
        other.streamUrl == streamUrl &&
        other.quality == quality &&
        sameList(other.qualities, qualities);
  }

  @override
  int get hashCode =>
      Object.hash(sessionId, streamUrl, quality, Object.hashAll(qualities));
}
