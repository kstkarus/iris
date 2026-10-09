class PlayerSession {
  const PlayerSession({
    required this.sessionId,
    required this.streamUrl,
    this.httpHeaders = const {},
  });

  final String sessionId;
  final String streamUrl;

  /// Sent with every request for the stream, its playlist and segments
  /// included, e.g. a Referer a video server asks for. Empty for torrents
  /// and local files.
  final Map<String, String> httpHeaders;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerSession &&
        other.sessionId == sessionId &&
        other.streamUrl == streamUrl &&
        _sameHeaders(other.httpHeaders, httpHeaders);
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    streamUrl,
    Object.hashAllUnordered(
      httpHeaders.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

bool _sameHeaders(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
