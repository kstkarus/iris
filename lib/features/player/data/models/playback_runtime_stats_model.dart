class PlaybackRuntimeStatsModel {
  const PlaybackRuntimeStatsModel({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;

  PlaybackRuntimeStatsModel copyWith({
    int? downloadRateBytesPerSecond,
    int? appMemoryBytes,
    bool clearAppMemoryBytes = false,
  }) {
    return PlaybackRuntimeStatsModel(
      downloadRateBytesPerSecond:
          downloadRateBytesPerSecond ?? this.downloadRateBytesPerSecond,
      appMemoryBytes: clearAppMemoryBytes
          ? null
          : appMemoryBytes ?? this.appMemoryBytes,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackRuntimeStatsModel &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.appMemoryBytes == appMemoryBytes;
  }

  @override
  int get hashCode => Object.hash(downloadRateBytesPerSecond, appMemoryBytes);
}
