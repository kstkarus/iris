class PlayerPlaybackStats {
  const PlayerPlaybackStats({
    required this.downloadRateBytesPerSecond,
    required this.appMemoryBytes,
  });

  final int downloadRateBytesPerSecond;
  final int? appMemoryBytes;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPlaybackStats &&
        other.downloadRateBytesPerSecond == downloadRateBytesPerSecond &&
        other.appMemoryBytes == appMemoryBytes;
  }

  @override
  int get hashCode => Object.hash(downloadRateBytesPerSecond, appMemoryBytes);
}
