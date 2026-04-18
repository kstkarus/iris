class PlaybackRuntimeStatsModel {
  const PlaybackRuntimeStatsModel({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
    required this.activePeers,
    required this.bufferSeconds,
    required this.bufferPieces,
    required this.readaheadWindow,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;
  final int activePeers;
  final double bufferSeconds;
  final int bufferPieces;
  final int readaheadWindow;

  PlaybackRuntimeStatsModel copyWith({
    int? downloadRateBytesPerSecond,
    int? appMemoryBytes,
    int? activePeers,
    double? bufferSeconds,
    int? bufferPieces,
    int? readaheadWindow,
    bool clearAppMemoryBytes = false,
  }) {
    return PlaybackRuntimeStatsModel(
      downloadRateBytesPerSecond:
          downloadRateBytesPerSecond ?? this.downloadRateBytesPerSecond,
      appMemoryBytes: clearAppMemoryBytes
          ? null
          : appMemoryBytes ?? this.appMemoryBytes,
      activePeers: activePeers ?? this.activePeers,
      bufferSeconds: bufferSeconds ?? this.bufferSeconds,
      bufferPieces: bufferPieces ?? this.bufferPieces,
      readaheadWindow: readaheadWindow ?? this.readaheadWindow,
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
        other.activePeers == activePeers &&
        other.bufferSeconds == bufferSeconds &&
        other.bufferPieces == bufferPieces &&
        other.readaheadWindow == readaheadWindow;
  }

  @override
  int get hashCode => Object.hash(
    downloadRateBytesPerSecond,
    appMemoryBytes,
    activePeers,
    bufferSeconds,
    bufferPieces,
    readaheadWindow,
  );
}
