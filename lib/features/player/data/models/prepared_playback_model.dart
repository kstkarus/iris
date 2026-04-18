class PreparedPlaybackModel {
  const PreparedPlaybackModel({
    required this.sessionId,
    required this.streamUrl,
  });

  final String sessionId;
  final String streamUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PreparedPlaybackModel &&
        other.sessionId == sessionId &&
        other.streamUrl == streamUrl;
  }

  @override
  int get hashCode => Object.hash(sessionId, streamUrl);
}
