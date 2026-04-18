class PlaybackRuntimeStatsModel {
  const PlaybackRuntimeStatsModel({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
    required this.activePeers,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;
  final int activePeers;

  PlaybackRuntimeStatsModel copyWith({
    int? downloadRateBytesPerSecond,
    int? appMemoryBytes,
    int? activePeers,
    bool clearAppMemoryBytes = false,
  }) {
    return PlaybackRuntimeStatsModel(
      downloadRateBytesPerSecond:
          downloadRateBytesPerSecond ?? this.downloadRateBytesPerSecond,
      appMemoryBytes: clearAppMemoryBytes
          ? null
          : appMemoryBytes ?? this.appMemoryBytes,
      activePeers: activePeers ?? this.activePeers,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackRuntimeStatsModel &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.appMemoryBytes == appMemoryBytes &&
        other.activePeers == activePeers;
  }

  @override
  int get hashCode =>
      Object.hash(downloadRateBytesPerSecond, appMemoryBytes, activePeers);
}
