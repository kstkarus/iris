class PlayerPlaybackStats {
  const PlayerPlaybackStats({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
    required this.activePeers,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;
  final int activePeers;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPlaybackStats &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.appMemoryBytes == appMemoryBytes &&
        other.activePeers == activePeers;
  }

  @override
  int get hashCode =>
      Object.hash(downloadRateBytesPerSecond, appMemoryBytes, activePeers);
}
